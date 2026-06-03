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
    token: localStorage.getItem('pharmacy_token') || '',
    user: JSON.parse(localStorage.getItem('pharmacy_user') || 'null'),
    pharmacy: null,
    activeSection: 'orders',
    notifications: [],
    incomingOrders: [],
    inventory: [],
    pollTimer: null
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
    if (notif.message.toLowerCase().includes('order') || notif.message.toLowerCase().includes('stock')) {
        playAlertSound();
    }
});

function playAlertSound() {
    try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        
        oscillator.type = 'triangle';
        oscillator.frequency.setValueAtTime(440, audioCtx.currentTime); // A4
        gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
        
        oscillator.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        
        oscillator.start();
        oscillator.stop(audioCtx.currentTime + 0.2);
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
    if (state.token && state.user && (state.user.role === 'pharmacy_owner' || state.user.role === 'pharmacist')) {
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

async function showApp() {
    document.getElementById('login-container').classList.add('hidden');
    document.getElementById('app-container').classList.remove('hidden');
    document.getElementById('owner-name').textContent = state.user.name || 'Pharmacy Owner';

    try {
        const res = await apiFetch(`${API_BASE}/pharmacies/my-pharmacy`);
        const data = await res.json();
        if (data.success) {
            state.pharmacy = data.data;
            document.getElementById('pharmacy-name-badge').textContent = state.pharmacy.name;
            document.getElementById('pharmacy-address-lbl').textContent = state.pharmacy.address;
        } else {
            alert("Warning: This account is not registered to a pharmacy yet. Contact admin to assign pharmacy owner ID.");
        }
    } catch(err) {
        console.error("Could not fetch pharmacy meta:", err);
    }

    switchSection(state.activeSection);
    startPolling();
}

function logout() {
    state.token = '';
    state.user = null;
    state.pharmacy = null;
    localStorage.removeItem('pharmacy_token');
    localStorage.removeItem('pharmacy_user');
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
                const uRole = resData.user.role;
                if (uRole !== 'pharmacy_owner' && uRole !== 'pharmacist') {
                    errorDiv.textContent = 'Access Denied: Only pharmacist or pharmacy owners permitted.';
                    return;
                }
                
                state.token = resData.token;
                state.user = resData.user;
                localStorage.setItem('pharmacy_token', state.token);
                localStorage.setItem('pharmacy_user', JSON.stringify(state.user));
                
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

    // Modal Control
    setupModalControl('stock-modal', 'close-stock-modal');

    // Add stock button
    document.getElementById('add-stock-btn').addEventListener('click', () => showStockModal());

    // Form Submit
    document.getElementById('stock-form').addEventListener('submit', handleStockSubmit);

    // Search Box Bindings
    document.getElementById('orders-search').addEventListener('input', renderIncomingOrders);
    document.getElementById('inventory-search').addEventListener('input', renderInventory);
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
        orders: 'Incoming Orders',
        inventory: 'Stock Inventory'
    };
    document.getElementById('section-title').textContent = titleMap[sectionId] || 'Pharmacy Hub';

    fetchSectionData(sectionId);
}

function fetchSectionData(sectionId) {
    if (!state.pharmacy) return;
    
    if (sectionId === 'orders') {
        refreshOrders();
    } else if (sectionId === 'inventory') {
        refreshInventory();
    }
}

// -------------------------------------------------------------
// 3-SECOND SHORT-POLLING
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
    if (!state.token || !state.pharmacy) return;
    
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
// ORDERS HANDLING (Incoming)
// -------------------------------------------------------------
async function refreshOrders() {
    try {
        const res = await apiFetch(`${API_BASE}/orders/pharmacy/incoming`);
        if (!res.ok) {
            const errData = await res.json().catch(() => ({}));
            const container = document.getElementById('orders-grid-container');
            if (container) {
                container.innerHTML = `<p class="empty-orders" style="color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> ${errData.message || 'Failed to fetch orders.'}</p>`;
            }
            return;
        }
        const data = await res.json();
        if (data.success) {
            state.incomingOrders = data.data || [];
            renderIncomingOrders();
        } else {
            const container = document.getElementById('orders-grid-container');
            if (container) {
                container.innerHTML = `<p class="empty-orders" style="color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> ${data.message || 'Failed to fetch orders.'}</p>`;
            }
        }
    } catch(e) {
        console.error("Orders fetch failed:", e);
        const container = document.getElementById('orders-grid-container');
        if (container) {
            container.innerHTML = `<p class="empty-orders" style="color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> Error connecting to server.</p>`;
        }
    }
}

function renderIncomingOrders() {
    const query = document.getElementById('orders-search').value.toLowerCase();
    const container = document.getElementById('orders-grid-container');
    
    const filtered = state.incomingOrders.filter(o => {
        const orderId = o.id ? String(o.id).toLowerCase() : '';
        const orderStatus = o.status ? String(o.status).toLowerCase() : '';
        const customerName = o.customer_name ? String(o.customer_name).toLowerCase() : '';
        const customerPhone = o.customer_phone ? String(o.customer_phone).toLowerCase() : '';
        return !query || 
               orderId.includes(query) || 
               orderStatus.includes(query) || 
               customerName.includes(query) ||
               customerPhone.includes(query);
    });

    if (filtered.length === 0) {
        container.innerHTML = `<p class="empty-orders">No customer orders matched your query.</p>`;
        return;
    }

    container.innerHTML = filtered.map(o => {
        const date = o.created_at ? new Date(o.created_at).toLocaleString() : 'N/A';
        const orderId = o.id ? String(o.id) : '';
        const shortId = orderId ? orderId.substring(0, 8) : 'N/A';
        const orderStatus = o.status ? String(o.status) : 'pending';
        const totalPrice = (o.total_price !== null && o.total_price !== undefined) ? Number(o.total_price) : 0.0;
        const formattedPrice = isNaN(totalPrice) ? '0.00' : totalPrice.toFixed(2);
        
        const medsList = Array.isArray(o.medicines) 
            ? o.medicines.map(m => `<li><i class="fa-solid fa-pills" style="color:var(--accent-color); font-size:0.8rem; margin-right:5px;"></i> ${m}</li>`).join('')
            : `<li>Prescribed items</li>`;
            
        let badgeClass = 'warning';
        if (orderStatus === 'accepted' || orderStatus === 'preparing') badgeClass = 'warning';
        if (orderStatus === 'ready' || orderStatus === 'delivered') badgeClass = 'active';
        if (orderStatus === 'rejected') badgeClass = 'inactive';

        let actionsHtml = '';
        if (orderStatus === 'pending' || orderStatus === 'assigned') {
            actionsHtml = `
                <button class="btn-accept" onclick="updateOrderStatus('${orderId}', 'preparing')"><i class="fa-solid fa-circle-check"></i> Accept</button>
                <button class="btn-reject" onclick="updateOrderStatus('${orderId}', 'rejected')"><i class="fa-solid fa-ban"></i> Reject</button>
            `;
        } else if (orderStatus === 'preparing') {
            actionsHtml = `
                <button class="btn-ready" onclick="updateOrderStatus('${orderId}', 'ready')"><i class="fa-solid fa-truck"></i> Ready for pickup</button>
            `;
        } else if (orderStatus === 'ready') {
            actionsHtml = `<small style="color:var(--text-secondary)"><i class="fa-solid fa-hourglass-half"></i> Waiting for driver claim</small>`;
        } else {
            actionsHtml = `<small style="color:var(--text-secondary)"><i class="fa-solid fa-circle-info"></i> Status: ${orderStatus.toUpperCase()}</small>`;
        }

        return `
            <div class="order-card">
                <div class="order-card-header">
                    <div>
                        <div class="order-id">Order #${shortId}</div>
                        <div class="order-time"><i class="fa-regular fa-clock"></i> ${date}</div>
                    </div>
                    <span class="badge ${badgeClass}">${orderStatus}</span>
                </div>
                
                <div class="order-items">
                    <strong>Medicines</strong>
                    <ul>
                        ${medsList}
                    </ul>
                </div>
                
                <div class="customer-detail">
                    <strong>Customer Detail</strong>
                    ${o.customer_name || 'Patient'}<br>
                    📞 ${o.customer_phone || 'No phone'}
                </div>
                
                <div class="order-card-footer">
                    <div class="order-price">${formattedPrice} EGP</div>
                    <div class="order-actions">
                        ${actionsHtml}
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

async function updateOrderStatus(orderId, newStatus) {
    try {
        const res = await apiFetch(`${API_BASE}/orders/${orderId}/status`, {
            method: 'PATCH',
            body: JSON.stringify({ status: newStatus })
        });
        const data = await res.json();
        if (data.success) {
            refreshOrders();
        } else {
            alert(data.message);
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// STOCK INVENTORY MANAGEMENT
// -------------------------------------------------------------
async function refreshInventory() {
    try {
        const res = await apiFetch(`${API_BASE}/pharmacies/my-pharmacy/inventory`);
        if (!res.ok) {
            const errData = await res.json().catch(() => ({}));
            const tbody = document.getElementById('inventory-table-body');
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> ${errData.message || 'Failed to fetch inventory.'}</td></tr>`;
            }
            return;
        }
        const data = await res.json();
        if (data.success) {
            state.inventory = data.data || [];
            renderInventory();
        } else {
            const tbody = document.getElementById('inventory-table-body');
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> ${data.message || 'Failed to fetch inventory.'}</td></tr>`;
            }
        }
    } catch(e) {
        console.error("Inventory fetch failed:", e);
        const tbody = document.getElementById('inventory-table-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:var(--danger-color);"><i class="fa-solid fa-triangle-exclamation"></i> Error connecting to server.</td></tr>`;
        }
    }
}

function renderInventory() {
    const query = document.getElementById('inventory-search').value.toLowerCase();
    const tbody = document.getElementById('inventory-table-body');
    
    const filtered = state.inventory.filter(i => {
        return !query || i.medicine_name.toLowerCase().includes(query) || (i.generic_name && i.generic_name.toLowerCase().includes(query));
    });

    tbody.innerHTML = filtered.map(i => `
        <tr>
            <td><strong>${i.medicine_name}</strong></td>
            <td>${i.batch_number || 'N/A'}</td>
            <td>${i.stock_quantity} units</td>
            <td>${i.price.toFixed(2)} EGP</td>
            <td>${i.expiry_date}</td>
            <td>
                <span class="badge ${i.is_prescription_required ? 'warning' : 'active'}">
                    ${i.is_prescription_required ? 'Yes' : 'No'}
                </span>
            </td>
            <td>
                <button class="btn-action edit" onclick="editInventory('${i.id}')"><i class="fa-regular fa-edit"></i> Edit</button>
                <button class="btn-action delete" onclick="deleteInventory('${i.id}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
            </td>
        </tr>
    `).join('');
}

function showStockModal(inv = null) {
    const modal = document.getElementById('stock-modal');
    const title = document.getElementById('stock-modal-title');
    const form = document.getElementById('stock-form');
    form.reset();
    
    const nextYear = new Date();
    nextYear.setFullYear(nextYear.getFullYear() + 1);
    document.getElementById('stock-expiry').value = nextYear.toISOString().substring(0, 10);
    
    if (inv) {
        title.textContent = "Edit Stock Level";
        document.getElementById('stock-id').value = inv.id;
        document.getElementById('stock-med-name').value = inv.medicine_name;
        document.getElementById('stock-med-name').readOnly = false;
        document.getElementById('stock-qty').value = inv.stock_quantity;
        document.getElementById('stock-price').value = inv.price;
        document.getElementById('stock-batch').value = inv.batch_number || 'B001';
        document.getElementById('stock-expiry').value = inv.expiry_date;
        document.getElementById('stock-presc-req').checked = !!inv.is_prescription_required;
    } else {
        title.textContent = "Add Stock Item";
        document.getElementById('stock-id').value = "";
        document.getElementById('stock-med-name').readOnly = false;
    }
    modal.classList.remove('hidden');
}

function editInventory(id) {
    const inv = state.inventory.find(i => i.id === id);
    if (inv) showStockModal(inv);
}

async function deleteInventory(inventoryId) {
    if (!confirm("Are you sure you want to remove this medicine from your inventory listing?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/pharmacies/my-pharmacy/inventory/${inventoryId}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshInventory();
    } catch(e) {}
}

async function handleStockSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('stock-id').value;
    const medicine_name = document.getElementById('stock-med-name').value;
    const stock_quantity = parseInt(document.getElementById('stock-qty').value);
    const price = parseFloat(document.getElementById('stock-price').value);
    const batch_number = document.getElementById('stock-batch').value;
    const expiry_date = document.getElementById('stock-expiry').value;
    const is_prescription_required = document.getElementById('stock-presc-req').checked;

    const payload = { id, medicine_name, stock_quantity, price, batch_number, expiry_date, is_prescription_required };

    try {
        const res = await apiFetch(`${API_BASE}/pharmacies/my-pharmacy/inventory`, {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.success) {
            document.getElementById('stock-modal').classList.add('hidden');
            refreshInventory();
        } else {
            alert(data.message);
        }
    } catch(err) {
        alert("Inventory update failed");
    }
}
