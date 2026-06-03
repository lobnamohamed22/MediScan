/**
 * Central State & Real-Time Event Broker
 * Decoupled UI and data communication layer to easily transition to WebSockets/Socket.IO in the future.
 */
class RealtimeBroker {
    constructor() {
        this.listeners = {};
    }
    
    on(event, callback) {
        if (!this.listeners[event]) {
            this.listeners[event] = [];
        }
        this.listeners[event].push(callback);
    }
    
    emit(event, data) {
        if (this.listeners[event]) {
            this.listeners[event].forEach(callback => {
                try {
                    callback(data);
                } catch (e) {
                    console.error(`Error in event listener for ${event}:`, e);
                }
            });
        }
    }
}

const eventBroker = new RealtimeBroker();

// Global App State
const state = {
    token: localStorage.getItem('delivery_token') || '',
    user: JSON.parse(localStorage.getItem('delivery_user') || 'null'),
    activeSection: 'unassigned',
    notifications: [],
    unassignedOrders: [],
    assignedOrders: [],
    pollTimer: null,
    activeGPSTracking: null
};

// API Base URL
const API_BASE = '/api';

// Fetch helper with auth header
async function apiFetch(url, options = {}) {
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };
    if (state.token) {
        headers['Authorization'] = `Bearer ${state.token}`;
    }
    const config = { ...options, headers };
    const response = await fetch(url, config);
    
    if (response.status === 401 || response.status === 403) {
        if (state.token) {
            logout();
        }
    }
    return response;
}

// -------------------------------------------------------------
// EVENT DISPATCHERS & ALERTS
// -------------------------------------------------------------
eventBroker.on('newNotification', (notif) => {
    if (notif.type === 'delivery' || notif.message.toLowerCase().includes('ready')) {
        playAlertSound();
    }
});

function playAlertSound() {
    try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        
        oscillator.type = 'sawtooth';
        oscillator.frequency.setValueAtTime(523.25, audioCtx.currentTime); // C5
        gainNode.gain.setValueAtTime(0.06, audioCtx.currentTime);
        
        oscillator.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        
        oscillator.start();
        oscillator.stop(audioCtx.currentTime + 0.25);
    } catch (e) {}
}

// -------------------------------------------------------------
// AUTHENTICATION & INITIALIZATION
// -------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
    initApp();
    setupEventListeners();
});

function initApp() {
    if (state.token && state.user && state.user.role === 'delivery') {
        showApp();
    } else {
        showLogin();
    }
}

function showLogin() {
    document.getElementById('login-container').classList.remove('hidden');
    document.getElementById('app-container').classList.add('hidden');
    stopPolling();
}

function showApp() {
    document.getElementById('login-container').classList.add('hidden');
    document.getElementById('app-container').classList.remove('hidden');
    document.getElementById('driver-name').textContent = state.user.name || 'Delivery Partner';
    
    switchSection(state.activeSection);
    startPolling();
}

function logout() {
    state.token = '';
    state.user = null;
    localStorage.removeItem('delivery_token');
    localStorage.removeItem('delivery_user');
    showLogin();
}

// -------------------------------------------------------------
// EVENT LISTENERS Setup
// -------------------------------------------------------------
function setupEventListeners() {
    // Login form submit
    document.getElementById('login-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('login-email').value;
        const password = document.getElementById('login-password').value;
        const errorDiv = document.getElementById('login-error');
        errorDiv.textContent = '';
        
        try {
            const res = await fetch(`${API_BASE}/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password })
            });
            const data = await res.json();
            
            if (data.success) {
                const resData = data.data || data;
                if (resData.user.role !== 'delivery') {
                    errorDiv.textContent = 'Access Denied: Only driver accounts are permitted.';
                    return;
                }
                if (!resData.user.is_verified) {
                    errorDiv.textContent = 'Access Denied: Your driver profile is pending Admin approval.';
                    return;
                }
                
                state.token = resData.token;
                state.user = resData.user;
                localStorage.setItem('delivery_token', state.token);
                localStorage.setItem('delivery_user', JSON.stringify(state.user));
                
                showApp();
            } else {
                errorDiv.textContent = data.message || 'Invalid Credentials';
            }
        } catch (err) {
            errorDiv.textContent = 'Server connection error. Please try again.';
        }
    });

    // Navigation switches
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const section = item.getAttribute('data-section');
            switchSection(section);
        });
    });

    // Logout
    document.getElementById('logout-btn').addEventListener('click', logout);

    // Notifications Toggler
    const bellBtn = document.getElementById('notif-bell-btn');
    const dropdown = document.getElementById('notif-dropdown');
    bellBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.classList.toggle('hidden');
    });
    
    document.addEventListener('click', () => {
        dropdown.classList.add('hidden');
    });
    dropdown.addEventListener('click', (e) => e.stopPropagation());

    // Dismiss notifications
    document.getElementById('clear-notifs-btn').addEventListener('click', async () => {
        try {
            await apiFetch(`${API_BASE}/notifications/read-all`, { method: 'PATCH' });
            refreshNotifications();
        } catch(e) {}
    });

    // GPS modal close controls
    setupModalControl('gps-modal', 'close-gps-modal');

    // GPS simulator slider changes
    document.getElementById('gps-slider').addEventListener('input', handleGPSSliderChange);

    // Send GPS Coordinates
    document.getElementById('send-gps-btn').addEventListener('click', handleGPSUpdateSubmit);

    // Search Box Bindings
    document.getElementById('unassigned-search').addEventListener('input', renderUnassignedOrders);
    document.getElementById('assigned-search').addEventListener('input', renderAssignedOrders);
}

function setupModalControl(modalId, closeBtnId) {
    const modal = document.getElementById(modalId);
    const closeBtn = document.getElementById(closeBtnId);
    
    closeBtn.addEventListener('click', () => modal.classList.add('hidden'));
    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.classList.add('hidden');
    });
}

// -------------------------------------------------------------
// NAVIGATION & DATA FETCHING
// -------------------------------------------------------------
function switchSection(sectionId) {
    state.activeSection = sectionId;
    
    document.querySelectorAll('.nav-item').forEach(item => {
        if (item.getAttribute('data-section') === sectionId) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    document.querySelectorAll('.content-section').forEach(sec => {
        sec.classList.add('hidden');
    });
    
    document.getElementById(`section-${sectionId}`).classList.remove('hidden');
    
    const titleMap = {
        unassigned: 'Claim Available Packages',
        assigned: 'My Deliveries'
    };
    document.getElementById('section-title').textContent = titleMap[sectionId] || 'Courier Portal';

    fetchSectionData(sectionId);
}

function fetchSectionData(sectionId) {
    if (sectionId === 'unassigned') {
        refreshUnassigned();
    } else if (sectionId === 'assigned') {
        refreshAssigned();
    }
}

// -------------------------------------------------------------
// 3-SECOND POLL LOOP
// -------------------------------------------------------------
function startPolling() {
    stopPolling();
    pollData();
    state.pollTimer = setInterval(pollData, 3000);
}

function stopPolling() {
    if (state.pollTimer) {
        clearInterval(state.pollTimer);
        state.pollTimer = null;
    }
}

async function pollData() {
    if (!state.token) return;
    
    try {
        const res = await apiFetch(`${API_BASE}/notifications`);
        const data = await res.json();
        if (data.success) {
            const incoming = data.data || [];
            
            const oldIds = new Set(state.notifications.map(n => n.id));
            incoming.forEach(notif => {
                if (!oldIds.has(notif.id)) {
                    eventBroker.emit('newNotification', notif);
                }
            });
            
            state.notifications = incoming;
            updateNotificationsUI();
        }
    } catch (e) {
        console.error("Notifications fetch failed:", e);
    }

    fetchSectionData(state.activeSection);
}

function updateNotificationsUI() {
    const badge = document.getElementById('notif-badge');
    const container = document.getElementById('notif-list-container');
    
    const unread = state.notifications.filter(n => !n.is_read).length;
    if (unread > 0) {
        badge.textContent = unread;
        badge.classList.remove('hidden');
    } else {
        badge.classList.add('hidden');
    }

    if (state.notifications.length === 0) {
        container.innerHTML = `<p class="empty-notifs">No notifications</p>`;
        return;
    }

    container.innerHTML = state.notifications.slice(0, 15).map(n => {
        const date = new Date(n.created_at).toLocaleTimeString();
        return `
            <div class="notif-item" style="border-left: 3px solid ${n.is_read ? 'transparent' : 'var(--accent-color)'}">
                <p>${n.message}</p>
                <div class="notif-meta">
                    <span>${date}</span>
                </div>
            </div>
        `;
    }).join('');
}

// -------------------------------------------------------------
// UNASSIGNED / CLAIM ORDERS
// -------------------------------------------------------------
async function refreshUnassigned() {
    try {
        const res = await apiFetch(`${API_BASE}/orders/delivery/unassigned`);
        const data = await res.json();
        if (data.success) {
            state.unassignedOrders = data.data || [];
            
            const countBadge = document.getElementById('unassigned-count-badge');
            if (state.unassignedOrders.length > 0) {
                countBadge.textContent = state.unassignedOrders.length;
                countBadge.classList.remove('hidden');
            } else {
                countBadge.classList.add('hidden');
            }
            
            renderUnassignedOrders();
        }
    } catch(e) {}
}

function renderUnassignedOrders() {
    const query = document.getElementById('unassigned-search').value.toLowerCase();
    const container = document.getElementById('unassigned-orders-container');
    
    const filtered = state.unassignedOrders.filter(o => {
        const pharmacyName = o.pharmacy_name ? String(o.pharmacy_name).toLowerCase() : '';
        const orderId = o.id ? String(o.id).toLowerCase() : '';
        return !query || pharmacyName.includes(query) || orderId.includes(query);
    });

    if (filtered.length === 0) {
        container.innerHTML = `<p class="empty-orders">No unassigned orders match your search.</p>`;
        return;
    }

    container.innerHTML = filtered.map(o => {
        const date = o.created_at ? new Date(o.created_at).toLocaleString() : 'N/A';
        const orderId = o.id ? String(o.id) : '';
        const orderStatus = o.status ? String(o.status) : 'pending';
        const totalPrice = (o.total_price !== null && o.total_price !== undefined) ? Number(o.total_price) : 0.0;
        const formattedPrice = isNaN(totalPrice) ? '0.00' : totalPrice.toFixed(2);
        const medsList = Array.isArray(o.medicines) 
            ? o.medicines.map(m => `<li><i class="fa-solid fa-pills" style="color:var(--accent-color); font-size:0.8rem; margin-right:5px;"></i> ${m}</li>`).join('')
            : `<li>Prescribed items</li>`;

        return `
            <div class="order-card">
                <div class="order-card-header">
                    <div>
                        <div class="order-id">Package Request</div>
                        <div class="order-time"><i class="fa-regular fa-clock"></i> ${date}</div>
                    </div>
                    <span class="badge warning">${orderStatus}</span>
                </div>
                
                <div class="order-items">
                    <strong>Medicines</strong>
                    <ul>
                        ${medsList}
                    </ul>
                </div>
                
                <div class="address-details">
                    <div class="address-point">
                        <strong>Pickup Pharmacy</strong>
                        ${o.pharmacy_name || 'Unknown'}<br>
                        📍 <span style="font-size:0.8rem; color:var(--text-secondary)">${o.pharmacy_address || ''}</span>
                    </div>
                </div>
                
                <div class="order-card-footer">
                    <div class="order-price">${formattedPrice} EGP</div>
                    <div class="order-actions">
                        <button class="btn-claim" onclick="claimOrderDelivery('${orderId}')"><i class="fa-solid fa-hand-holding-medical"></i> Accept Delivery</button>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

async function claimOrderDelivery(orderId) {
    try {
        const res = await apiFetch(`${API_BASE}/orders/${orderId}/accept-delivery`, {
            method: 'PATCH'
        });
        const data = await res.json();
        if (data.success) {
            switchSection('assigned');
        } else {
            alert(data.message);
        }
    } catch(err) {
        alert("Could not accept delivery request");
    }
}

// -------------------------------------------------------------
// MY ASSIGNED DELIVERIES
// -------------------------------------------------------------
async function refreshAssigned() {
    try {
        const res = await apiFetch(`${API_BASE}/orders/delivery/assigned`);
        const data = await res.json();
        if (data.success) {
            state.assignedOrders = data.data || [];
            renderAssignedOrders();
        }
    } catch(e) {}
}

function renderAssignedOrders() {
    const query = document.getElementById('assigned-search').value.toLowerCase();
    const container = document.getElementById('assigned-orders-container');
    
    const activeAssigned = state.assignedOrders.filter(o => o.status !== 'delivered' && o.status !== 'rejected');

    const filtered = activeAssigned.filter(o => {
        const orderId = o.id ? String(o.id).toLowerCase() : '';
        const pharmacyName = o.pharmacy_name ? String(o.pharmacy_name).toLowerCase() : '';
        const customerName = o.customer_name ? String(o.customer_name).toLowerCase() : '';
        const orderStatus = o.status ? String(o.status).toLowerCase() : '';
        return !query || 
               orderId.includes(query) || 
               pharmacyName.includes(query) || 
               customerName.includes(query) ||
               orderStatus.includes(query);
    });

    if (filtered.length === 0) {
        container.innerHTML = `<p class="empty-orders">No current active deliveries matched your query.</p>`;
        return;
    }

    container.innerHTML = filtered.map(o => {
        const date = o.created_at ? new Date(o.created_at).toLocaleString() : 'N/A';
        const orderId = o.id ? String(o.id) : '';
        const shortId = orderId ? orderId.substring(0, 8) : 'N/A';
        const orderStatus = o.status ? String(o.status) : 'pending';
        const totalPrice = (o.total_price !== null && o.total_price !== undefined) ? Number(o.total_price) : 0.0;
        const formattedPrice = isNaN(totalPrice) ? '0.00' : totalPrice.toFixed(2);
        
        let nextStatusLabel = '';
        let nextStatusValue = '';
        let statusIcon = '';
        if (orderStatus === 'assigned') {
            nextStatusLabel = 'Mark Picked Up';
            nextStatusValue = 'picked_up';
            statusIcon = '<i class="fa-solid fa-clipboard-check"></i> ';
        } else if (orderStatus === 'picked_up') {
            nextStatusLabel = 'Mark In Transit';
            nextStatusValue = 'in_transit';
            statusIcon = '<i class="fa-solid fa-truck-fast"></i> ';
        } else if (orderStatus === 'in_transit') {
            nextStatusLabel = 'Mark Delivered';
            nextStatusValue = 'delivered';
            statusIcon = '<i class="fa-solid fa-house-circle-check"></i> ';
        }

        const actionButtons = nextStatusValue 
            ? `<button class="btn-update" onclick="updateDeliveryStatus('${orderId}', '${nextStatusValue}')">${statusIcon}${nextStatusLabel}</button>`
            : '';

        const gpsButton = (orderStatus === 'picked_up' || orderStatus === 'in_transit')
            ? `<button class="btn-gps" onclick="openGPSSimulator('${orderId}')"><i class="fa-solid fa-location-crosshairs"></i> GPS Sim</button>`
            : '';

        return `
            <div class="order-card">
                <div class="order-card-header">
                    <div>
                        <div class="order-id">Order #${shortId}</div>
                        <div class="order-time"><i class="fa-regular fa-clock"></i> ${date}</div>
                    </div>
                    <span class="badge warning">${orderStatus}</span>
                </div>
                
                <div class="address-details">
                    <div class="address-point">
                        <strong>Pickup Pharmacy</strong>
                        ${o.pharmacy_name || 'Unknown'}
                    </div>
                    <div class="address-point customer">
                        <strong>Customer Delivery Address</strong>
                        Customer Name: ${o.customer_name || 'Patient'}<br>
                        Phone: ${o.customer_phone || 'N/A'}
                    </div>
                </div>
                
                <div class="order-card-footer">
                    <div class="order-price">${formattedPrice} EGP</div>
                    <div class="order-actions">
                        ${gpsButton}
                        ${actionButtons}
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

async function updateDeliveryStatus(orderId, nextStatus) {
    try {
        const res = await apiFetch(`${API_BASE}/orders/${orderId}/status`, {
            method: 'PATCH',
            body: JSON.stringify({ status: nextStatus })
        });
        const data = await res.json();
        if (data.success) {
            refreshAssigned();
        } else {
            alert(data.message);
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// GPS COORDINATES ROUTE SIMULATION
// -------------------------------------------------------------
async function openGPSSimulator(orderId) {
    try {
        const res = await apiFetch(`${API_BASE}/orders/${orderId}/tracking`);
        const data = await res.json();
        
        if (data.success) {
            const tr = data.data;
            state.activeGPSTracking = {
                orderId: orderId,
                pLat: tr.pharmacy_lat || 30.0544,
                pLng: tr.pharmacy_lng || 31.2457,
                cLat: tr.customer_lat || 30.0444,
                cLng: tr.customer_lng || 31.2357
            };

            document.getElementById('gps-order-id').value = orderId;
            document.getElementById('gps-pharm-lbl').textContent = `${state.activeGPSTracking.pLat.toFixed(6)}, ${state.activeGPSTracking.pLng.toFixed(6)}`;
            document.getElementById('gps-cust-lbl').textContent = `${state.activeGPSTracking.cLat.toFixed(6)}, ${state.activeGPSTracking.cLng.toFixed(6)}`;
            
            document.getElementById('gps-slider').value = 0;
            document.getElementById('sim-lat').value = state.activeGPSTracking.pLat.toFixed(6);
            document.getElementById('sim-lng').value = state.activeGPSTracking.pLng.toFixed(6);
            document.getElementById('gps-status-msg').textContent = '';

            document.getElementById('gps-modal').classList.remove('hidden');
        }
    } catch(e) {
        alert("Failed to initialize GPS route metadata");
    }
}

function handleGPSSliderChange(e) {
    if (!state.activeGPSTracking) return;
    
    const progress = parseInt(e.target.value) / 100.0;
    
    const lat = state.activeGPSTracking.pLat + (state.activeGPSTracking.cLat - state.activeGPSTracking.pLat) * progress;
    const lng = state.activeGPSTracking.pLng + (state.activeGPSTracking.cLng - state.activeGPSTracking.pLng) * progress;
    
    document.getElementById('sim-lat').value = lat.toFixed(6);
    document.getElementById('sim-lng').value = lng.toFixed(6);
}

async function handleGPSUpdateSubmit() {
    if (!state.activeGPSTracking) return;
    
    const orderId = state.activeGPSTracking.orderId;
    const lat = parseFloat(document.getElementById('sim-lat').value);
    const lng = parseFloat(document.getElementById('sim-lng').value);
    const statusMsg = document.getElementById('gps-status-msg');

    statusMsg.textContent = 'Updating coordinates...';

    try {
        const res = await apiFetch(`${API_BASE}/orders/${orderId}/location`, {
            method: 'PATCH',
            body: JSON.stringify({ lat, lng })
        });
        const data = await res.json();
        if (data.success) {
            statusMsg.textContent = '📍 Coordinates updated successfully!';
            setTimeout(() => {
                statusMsg.textContent = '';
            }, 2000);
        } else {
            statusMsg.textContent = `Error: ${data.message}`;
        }
    } catch(err) {
        statusMsg.textContent = 'Error connecting to GPS API';
    }
}
