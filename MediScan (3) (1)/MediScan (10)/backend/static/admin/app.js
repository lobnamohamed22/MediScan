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
    token: localStorage.getItem('admin_token') || '',
    user: JSON.parse(localStorage.getItem('admin_user') || 'null'),
    activeSection: 'analytics',
    notifications: [],
    users: [],
    pharmacies: [],
    medicines: [],
    inventory: [],
    prescriptions: [],
    orders: [],
    drivers: [],
    pollTimer: null
};

// Chart Instance
let revenueChart = null;

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
// EVENT HANDLERS & NOTIFICATION DISPATCHING
// -------------------------------------------------------------
eventBroker.on('newNotification', (notif) => {
    const logContainer = document.getElementById('analytics-live-logs');
    if (logContainer) {
        const emptyMsg = logContainer.querySelector('.empty-notifs');
        if (emptyMsg) emptyMsg.remove();
        
        const entry = document.createElement('div');
        entry.className = `log-entry ${notif.type || 'system'}`;
        
        const timeStr = new Date(notif.created_at).toLocaleTimeString();
        
        let typeIcon = '<i class="fa-solid fa-info-circle"></i>';
        if (notif.type === 'order') typeIcon = '<i class="fa-solid fa-cart-shopping"></i>';
        if (notif.type === 'delivery') typeIcon = '<i class="fa-solid fa-truck"></i>';
        if (notif.type === 'pharmacy') typeIcon = '<i class="fa-solid fa-house-medical"></i>';
        
        entry.innerHTML = `
            <div>
                <span class="log-type-icon">${typeIcon}</span>
                <strong>[${(notif.type || 'system').toUpperCase()}]</strong> ${notif.message}
                <span style="color: var(--text-secondary); font-size: 0.8rem; margin-left: 5px;">(User: ${notif.user_name || 'System'})</span>
            </div>
            <span class="log-time">${timeStr}</span>
        `;
        
        logContainer.insertBefore(entry, logContainer.firstChild);
        if (logContainer.children.length > 30) {
            logContainer.lastChild.remove();
        }
    }
    
    if (notif.type === 'order' || notif.type === 'delivery') {
        playAlertSound();
    }
});

function playAlertSound() {
    try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        
        oscillator.type = 'sine';
        oscillator.frequency.setValueAtTime(587.33, audioCtx.currentTime); // D5
        gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
        
        oscillator.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        
        oscillator.start();
        oscillator.stop(audioCtx.currentTime + 0.15);
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
    if (state.token && state.user && state.user.role === 'admin') {
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
    document.getElementById('admin-name').textContent = state.user.name || 'System Admin';
    
    switchSection(state.activeSection);
    startPolling();
}

function logout() {
    state.token = '';
    state.user = null;
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    if (revenueChart) {
        revenueChart.destroy();
        revenueChart = null;
    }
    showLogin();
}

// -------------------------------------------------------------
// DOM EVENT LISTENERS (Search, Filters, Actions)
// -------------------------------------------------------------
function setupEventListeners() {
    // Login
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
                if (resData.user.role !== 'admin') {
                    errorDiv.textContent = 'Access Denied: Only Admin accounts are permitted.';
                    return;
                }
                
                state.token = resData.token;
                state.user = resData.user;
                localStorage.setItem('admin_token', state.token);
                localStorage.setItem('admin_user', JSON.stringify(state.user));
                
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

    // Modals Close Control
    setupModalControl('user-modal', 'close-user-modal');
    setupModalControl('pharmacy-modal', 'close-pharmacy-modal');
    setupModalControl('medicine-modal', 'close-medicine-modal');
    setupModalControl('inventory-modal', 'close-inventory-modal');
    setupModalControl('order-modal', 'close-order-modal');

    // Add buttons
    document.getElementById('add-user-btn').addEventListener('click', () => showUserModal());
    document.getElementById('add-pharmacy-btn').addEventListener('click', () => showPharmacyModal());
    document.getElementById('add-medicine-btn').addEventListener('click', () => showMedicineModal());
    document.getElementById('add-inventory-btn').addEventListener('click', () => showInventoryModal());

    // Form Submissions
    document.getElementById('user-form').addEventListener('submit', handleUserSubmit);
    document.getElementById('pharmacy-form').addEventListener('submit', handlePharmacySubmit);
    document.getElementById('medicine-form').addEventListener('submit', handleMedicineSubmit);
    document.getElementById('inventory-form').addEventListener('submit', handleInventorySubmit);
    document.getElementById('order-form').addEventListener('submit', handleOrderSubmit);

    // Search and filter triggers (Local Filtering for ultra-snappy UX)
    document.getElementById('users-search').addEventListener('input', renderUsers);
    document.getElementById('users-filter-role').addEventListener('change', renderUsers);

    document.getElementById('pharmacies-search').addEventListener('input', renderPharmacies);
    document.getElementById('pharmacies-filter-status').addEventListener('change', renderPharmacies);

    document.getElementById('medicines-search').addEventListener('input', renderMedicines);

    document.getElementById('inventory-search').addEventListener('input', renderInventory);
    document.getElementById('inventory-filter-pharmacy').addEventListener('change', renderInventory);

    document.getElementById('prescriptions-search').addEventListener('input', renderPrescriptions);
    document.getElementById('prescriptions-filter-status').addEventListener('change', renderPrescriptions);

    document.getElementById('orders-search').addEventListener('input', renderOrders);
    document.getElementById('orders-filter-status').addEventListener('change', renderOrders);
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
// SECTION SWITCHER
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
    
    const targetSection = document.getElementById(`section-${sectionId}`);
    if (targetSection) {
        targetSection.classList.remove('hidden');
    }

    const titleMap = {
        analytics: 'System Analytics',
        users: 'User Account Registry',
        pharmacies: 'Pharmacy Control Panel',
        medicines: 'Central Medicine Catalog',
        inventory: 'Global Stock Inventory',
        prescriptions: 'Customer Prescriptions',
        orders: 'Delivery Order Center'
    };
    document.getElementById('section-title').textContent = titleMap[sectionId] || 'MediScan Admin';

    fetchSectionData(sectionId);
}

function fetchSectionData(sectionId) {
    switch (sectionId) {
        case 'analytics':
            refreshAnalytics();
            break;
        case 'users':
            refreshUsers();
            break;
        case 'pharmacies':
            refreshPharmacies();
            break;
        case 'medicines':
            refreshMedicines();
            break;
        case 'inventory':
            refreshInventory();
            break;
        case 'prescriptions':
            refreshPrescriptions();
            break;
        case 'orders':
            refreshOrders();
            break;
    }
}

// -------------------------------------------------------------
// SHORT-POLLING
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
        const res = await apiFetch(`${API_BASE}/admin/notifications`);
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
        console.error("Polling notifications failed:", e);
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
        container.innerHTML = `<p class="empty-notifs">No recent notifications</p>`;
        return;
    }

    container.innerHTML = state.notifications.map(n => {
        const date = new Date(n.created_at).toLocaleTimeString();
        return `
            <div class="notif-item" style="border-left: 3px solid ${n.is_read ? 'transparent' : 'var(--accent-color)'}">
                <p><strong>[${n.type.toUpperCase()}]</strong> ${n.message}</p>
                <div class="notif-meta">
                    <span>by ${n.user_name || 'System'}</span>
                    <span>${date}</span>
                </div>
            </div>
        `;
    }).join('');
}

// -------------------------------------------------------------
// ANALYTICS & GRAPH RENDER
// -------------------------------------------------------------
async function refreshAnalytics() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/analytics`);
        const data = await res.json();
        if (data.success) {
            const rVal = data.data.revenue || 0.0;
            document.getElementById('metric-revenue').textContent = `${rVal.toFixed(2)} EGP`;
            document.getElementById('metric-orders').textContent = data.data.total_orders;
            document.getElementById('metric-users').textContent = data.data.total_users;
            document.getElementById('metric-pharmacies').textContent = data.data.total_pharmacies;
            
            // Draw Chart.js Line Chart
            renderRevenueChart(rVal);
        }
    } catch(e) {}
}

function renderRevenueChart(revenue) {
    const canvas = document.getElementById('revenue-chart-canvas');
    if (!canvas) return;
    
    const baseVal = revenue > 0 ? (revenue / 7) : 120.0;
    const dailyData = [
        baseVal * 0.7,
        baseVal * 1.1,
        baseVal * 0.9,
        baseVal * 1.3,
        baseVal * 0.8,
        baseVal * 1.2,
        baseVal * 1.0
    ];
    
    if (revenueChart) {
        revenueChart.data.datasets[0].data = dailyData;
        revenueChart.update();
        return;
    }
    
    const ctx = canvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 250);
    gradient.addColorStop(0, 'rgba(59, 130, 246, 0.35)');
    gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');
    
    revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            datasets: [{
                label: 'Sales EGP',
                data: dailyData,
                borderColor: '#3b82f6',
                borderWidth: 2.5,
                backgroundColor: gradient,
                fill: true,
                tension: 0.35,
                pointBackgroundColor: '#3b82f6',
                pointBorderColor: '#0b0f19',
                pointRadius: 4,
                pointHoverRadius: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                x: { grid: { display: false }, ticks: { color: '#8492a6' } },
                y: { grid: { color: 'rgba(255, 255, 255, 0.04)' }, ticks: { color: '#8492a6' } }
            }
        }
    });
}

// -------------------------------------------------------------
// USER CRUD & RENDER
// -------------------------------------------------------------
async function refreshUsers() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/users`);
        const data = await res.json();
        if (data.success) {
            state.users = data.data || [];
            state.drivers = state.users.filter(u => u.role === 'delivery');
            renderUsers();
        }
    } catch(e) {}
}

function renderUsers() {
    const query = document.getElementById('users-search').value.toLowerCase();
    const roleFilter = document.getElementById('users-filter-role').value;
    
    const filtered = state.users.filter(u => {
        const matchQuery = !query || u.name.toLowerCase().includes(query) || u.email.toLowerCase().includes(query) || u.phone.includes(query);
        const matchRole = !roleFilter || u.role === roleFilter;
        return matchQuery && matchRole;
    });

    const tbody = document.getElementById('users-table-body');
    tbody.innerHTML = filtered.map(u => `
        <tr>
            <td><strong>${u.name}</strong></td>
            <td>${u.email}</td>
            <td>${u.phone}</td>
            <td><span class="badge active" style="background:rgba(59,130,246,0.1); color:#3b82f6; border-color:transparent;">${u.role}</span></td>
            <td>
                <span class="badge ${u.is_verified ? 'active' : 'inactive'}">
                    ${u.is_verified ? 'Approved' : 'Disabled'}
                </span>
            </td>
            <td>
                <button class="btn-action edit" onclick="editUser('${u.id}')"><i class="fa-regular fa-edit"></i> Edit</button>
                <button class="btn-action delete" onclick="deleteUser('${u.id}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
            </td>
        </tr>
    `).join('');
}

function showUserModal(user = null) {
    const modal = document.getElementById('user-modal');
    const title = document.getElementById('user-modal-title');
    const form = document.getElementById('user-form');
    form.reset();
    
    if (user) {
        title.textContent = "Edit User Settings";
        document.getElementById('user-id').value = user.id;
        document.getElementById('user-name').value = user.name || '';
        document.getElementById('user-email').value = user.email || '';
        document.getElementById('user-phone').value = user.phone || '';
        document.getElementById('user-role').value = user.role || 'patient';
        document.getElementById('user-gender').value = user.gender || 'Other';
        document.getElementById('user-verified').checked = !!user.is_verified;
        document.getElementById('user-password').placeholder = "Enter new password (optional)";
        document.getElementById('user-password').required = false;
    } else {
        title.textContent = "Add New User";
        document.getElementById('user-id').value = "";
        document.getElementById('user-verified').checked = false;
        document.getElementById('user-password').placeholder = "";
        document.getElementById('user-password').required = true;
    }
    modal.classList.remove('hidden');
}

function editUser(userId) {
    const user = state.users.find(u => u.id === userId);
    if (user) showUserModal(user);
}

async function deleteUser(userId) {
    if (!confirm("Are you sure you want to completely delete this user?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/admin/users/${userId}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshUsers();
    } catch(e) {}
}

async function handleUserSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('user-id').value;
    const full_name = document.getElementById('user-name').value;
    const email = document.getElementById('user-email').value;
    const phone = document.getElementById('user-phone').value;
    const password = document.getElementById('user-password').value;
    const role = document.getElementById('user-role').value;
    const gender = document.getElementById('user-gender').value;
    const is_verified = document.getElementById('user-verified').checked;

    const payload = { full_name, email, phone, role, gender, is_verified };
    if (password) payload.password = password;

    const url = id ? `${API_BASE}/admin/users/${id}` : `${API_BASE}/admin/users`;
    const method = id ? 'PATCH' : 'POST';

    try {
        const res = await apiFetch(url, { method, body: JSON.stringify(payload) });
        if ((await res.json()).success) {
            document.getElementById('user-modal').classList.add('hidden');
            refreshUsers();
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// PHARMACIES CRUD & RENDER
// -------------------------------------------------------------
async function refreshPharmacies() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/pharmacies`);
        const data = await res.json();
        if (data.success) {
            state.pharmacies = data.data || [];
            renderPharmacies();
        }
    } catch(e) {}
}

function renderPharmacies() {
    const query = document.getElementById('pharmacies-search').value.toLowerCase();
    const statusFilter = document.getElementById('pharmacies-filter-status').value;

    const filtered = state.pharmacies.filter(p => {
        const matchQuery = !query || p.name.toLowerCase().includes(query) || p.address.toLowerCase().includes(query) || (p.owner_id && p.owner_id.includes(query));
        const matchStatus = !statusFilter || (statusFilter === 'active' ? p.is_active : !p.is_active);
        return matchQuery && matchStatus;
    });

    const tbody = document.getElementById('pharmacies-table-body');
    tbody.innerHTML = filtered.map(p => `
        <tr>
            <td><strong>${p.name}</strong></td>
            <td>${p.address}</td>
            <td>${p.phone || 'N/A'}</td>
            <td>⭐ ${p.rating.toFixed(1)}</td>
            <td><small style="color:var(--text-secondary)">${p.owner_id || 'No Owner'}</small></td>
            <td>
                <span class="badge ${p.is_active ? 'active' : 'inactive'}">
                    ${p.is_active ? 'Active' : 'Disabled'}
                </span>
            </td>
            <td>
                <button class="btn-action edit" onclick="togglePharmacyApproval('${p.id}', ${!p.is_active})">
                    <i class="fa-solid ${p.is_active ? 'fa-ban' : 'fa-circle-check'}"></i> ${p.is_active ? 'Disable' : 'Approve'}
                </button>
                <button class="btn-action edit" onclick="editPharmacy('${p.id}')"><i class="fa-regular fa-edit"></i> Edit</button>
                <button class="btn-action delete" onclick="deletePharmacy('${p.id}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
            </td>
        </tr>
    `).join('');
}

async function togglePharmacyApproval(id, is_approved) {
    try {
        const res = await apiFetch(`${API_BASE}/admin/pharmacies/${id}/approve`, {
            method: 'PATCH',
            body: JSON.stringify({ is_approved })
        });
        if ((await res.json()).success) refreshPharmacies();
    } catch(e) {}
}

function showPharmacyModal(pharmacy = null) {
    const modal = document.getElementById('pharmacy-modal');
    const title = document.getElementById('pharmacy-modal-title');
    const form = document.getElementById('pharmacy-form');
    form.reset();
    
    if (pharmacy) {
        title.textContent = "Edit Pharmacy Info";
        document.getElementById('pharmacy-id').value = pharmacy.id;
        document.getElementById('pharmacy-name').value = pharmacy.name;
        document.getElementById('pharmacy-address').value = pharmacy.address;
        document.getElementById('pharmacy-lat').value = pharmacy.latitude || 30.0544;
        document.getElementById('pharmacy-lng').value = pharmacy.longitude || 31.2457;
        document.getElementById('pharmacy-phone').value = pharmacy.phone || '';
        document.getElementById('pharmacy-owner').value = pharmacy.owner_id || '';
        document.getElementById('pharmacy-active').checked = !!pharmacy.is_active;
        document.getElementById('pharmacy-delivery').checked = !!pharmacy.delivery_available;
    } else {
        title.textContent = "Register Pharmacy";
        document.getElementById('pharmacy-id').value = "";
        document.getElementById('pharmacy-lat').value = 30.0544;
        document.getElementById('pharmacy-lng').value = 31.2457;
        document.getElementById('pharmacy-active').checked = true;
        document.getElementById('pharmacy-delivery').checked = true;
    }
    modal.classList.remove('hidden');
}

function editPharmacy(id) {
    const p = state.pharmacies.find(ph => ph.id === id);
    if (p) showPharmacyModal(p);
}

async function deletePharmacy(id) {
    if (!confirm("Delete this pharmacy and all associated inventory?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/admin/pharmacies/${id}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshPharmacies();
    } catch(e) {}
}

async function handlePharmacySubmit(e) {
    e.preventDefault();
    const id = document.getElementById('pharmacy-id').value;
    const name = document.getElementById('pharmacy-name').value;
    const address = document.getElementById('pharmacy-address').value;
    const latitude = parseFloat(document.getElementById('pharmacy-lat').value);
    const longitude = parseFloat(document.getElementById('pharmacy-lng').value);
    const phone = document.getElementById('pharmacy-phone').value;
    const owner_id = document.getElementById('pharmacy-owner').value;
    const is_active = document.getElementById('pharmacy-active').checked;
    const delivery_available = document.getElementById('pharmacy-delivery').checked;

    const payload = { name, address, latitude, longitude, phone, owner_id, is_active, delivery_available };
    const url = id ? `${API_BASE}/admin/pharmacies/${id}` : `${API_BASE}/admin/pharmacies`;
    const method = id ? 'PATCH' : 'POST';

    try {
        const res = await apiFetch(url, { method, body: JSON.stringify(payload) });
        if ((await res.json()).success) {
            document.getElementById('pharmacy-modal').classList.add('hidden');
            refreshPharmacies();
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// MEDICINE CATALOG & RENDER
// -------------------------------------------------------------
async function refreshMedicines() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/medicines`);
        const data = await res.json();
        if (data.success) {
            state.medicines = data.data || [];
            renderMedicines();
        }
    } catch(e) {}
}

function renderMedicines() {
    const query = document.getElementById('medicines-search').value.toLowerCase();
    
    const filtered = state.medicines.filter(m => !query || m.medicine_name.toLowerCase().includes(query) || (m.generic_name && m.generic_name.toLowerCase().includes(query)));
    
    const tbody = document.getElementById('medicines-table-body');
    tbody.innerHTML = filtered.map(m => `
        <tr>
            <td>
                <img src="${m.medicine_image || '/uploads/medicine_placeholder.png'}" 
                     class="medicine-thumb" onerror="this.src='/uploads/medicine_placeholder.png'">
            </td>
            <td><strong>${m.medicine_name}</strong></td>
            <td>${m.generic_name || 'N/A'}</td>
            <td>${m.dosage_adult || 'N/A'}</td>
            <td><small>${(m.uses || 'N/A').substring(0, 50)}...</small></td>
            <td>
                <button class="btn-action edit" onclick="editMedicine(${m.id})"><i class="fa-regular fa-edit"></i> Edit</button>
                <button class="btn-action delete" onclick="deleteMedicine(${m.id})"><i class="fa-regular fa-trash-can"></i> Delete</button>
            </td>
        </tr>
    `).join('');
}

function showMedicineModal(med = null) {
    const modal = document.getElementById('medicine-modal');
    const title = document.getElementById('medicine-modal-title');
    const form = document.getElementById('medicine-form');
    form.reset();
    
    if (med) {
        title.textContent = "Edit Catalog Medicine";
        document.getElementById('medicine-id').value = med.id;
        document.getElementById('med-name').value = med.medicine_name;
        document.getElementById('med-generic').value = med.generic_name || '';
        document.getElementById('med-image').value = med.medicine_image || '';
        document.getElementById('med-dosage-adult').value = med.dosage_adult || '';
        document.getElementById('med-dosage-child').value = med.dosage_child || '';
        document.getElementById('med-uses').value = med.uses || '';
        document.getElementById('med-side-effects').value = med.side_effects || '';
    } else {
        title.textContent = "Catalog New Medicine";
        document.getElementById('medicine-id').value = "";
    }
    modal.classList.remove('hidden');
}

function editMedicine(id) {
    const med = state.medicines.find(m => m.id === id);
    if (med) showMedicineModal(med);
}

async function deleteMedicine(id) {
    if (!confirm("Warning: Deleting catalog entries affects inventory stock lists. Continue?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/admin/medicines/${id}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshMedicines();
    } catch(e) {}
}

async function handleMedicineSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('medicine-id').value;
    const medicine_name = document.getElementById('med-name').value;
    const generic_name = document.getElementById('med-generic').value;
    const medicine_image = document.getElementById('med-image').value;
    const dosage_adult = document.getElementById('med-dosage-adult').value;
    const dosage_child = document.getElementById('med-dosage-child').value;
    const uses = document.getElementById('med-uses').value;
    const side_effects = document.getElementById('med-side-effects').value;

    const payload = { medicine_name, generic_name, medicine_image, dosage_adult, dosage_child, uses, side_effects };
    const url = id ? `${API_BASE}/admin/medicines/${id}` : `${API_BASE}/admin/medicines`;
    const method = id ? 'PATCH' : 'POST';

    try {
        const res = await apiFetch(url, { method, body: JSON.stringify(payload) });
        if ((await res.json()).success) {
            document.getElementById('medicine-modal').classList.add('hidden');
            refreshMedicines();
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// STOCK INVENTORY CRUD & RENDER
// -------------------------------------------------------------
async function refreshInventory() {
    try {
        const pRes = await apiFetch(`${API_BASE}/admin/pharmacies`);
        const pData = await pRes.json();
        if (pData.success) {
            state.pharmacies = pData.data || [];
            
            // Populate filter select
            const filterSel = document.getElementById('inventory-filter-pharmacy');
            filterSel.innerHTML = '<option value="">All Pharmacies</option>' + 
                state.pharmacies.map(p => `<option value="${p.id}">${p.name}</option>`).join('');
                
            // Populate modal select
            const select = document.getElementById('inv-pharmacy-id');
            select.innerHTML = state.pharmacies.map(p => `<option value="${p.id}">${p.name}</option>`).join('');
        }

        const res = await apiFetch(`${API_BASE}/admin/inventory`);
        const data = await res.json();
        if (data.success) {
            state.inventory = data.data || [];
            renderInventory();
        }
    } catch(e) {}
}

function renderInventory() {
    const query = document.getElementById('inventory-search').value.toLowerCase();
    const pharmFilter = document.getElementById('inventory-filter-pharmacy').value;
    
    const filtered = state.inventory.filter(i => {
        const matchQuery = !query || i.medicine_name.toLowerCase().includes(query);
        const matchPharm = !pharmFilter || i.pharmacy_id === pharmFilter;
        return matchQuery && matchPharm;
    });

    const tbody = document.getElementById('inventory-table-body');
    tbody.innerHTML = filtered.map(i => {
        const pharm = state.pharmacies.find(p => p.id === i.pharmacy_id);
        const pharmName = pharm ? pharm.name : 'Unknown Pharmacy';
        return `
            <tr>
                <td><strong>${i.medicine_name}</strong></td>
                <td>${pharmName}</td>
                <td>${i.stock_quantity} units</td>
                <td>${i.price.toFixed(2)} EGP</td>
                <td>${i.expiry_date}</td>
                <td><span class="badge ${i.is_prescription_required ? 'active' : 'inactive'}">${i.is_prescription_required ? 'Yes' : 'No'}</span></td>
                <td>
                    <button class="btn-action edit" onclick="editInventory('${i.id}')"><i class="fa-regular fa-edit"></i> Edit</button>
                    <button class="btn-action delete" onclick="deleteInventory('${i.id}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
                </td>
            </tr>
        `;
    }).join('');
}

function showInventoryModal(inv = null) {
    const modal = document.getElementById('inventory-modal');
    const title = document.getElementById('inventory-modal-title');
    const form = document.getElementById('inventory-form');
    form.reset();
    
    const nextYear = new Date();
    nextYear.setFullYear(nextYear.getFullYear() + 1);
    document.getElementById('inv-expiry').value = nextYear.toISOString().substring(0, 10);
    
    if (inv) {
        title.textContent = "Edit Stock Level";
        document.getElementById('inventory-id').value = inv.id;
        document.getElementById('inv-pharmacy-id').value = inv.pharmacy_id;
        document.getElementById('inv-med-name').value = inv.medicine_name;
        document.getElementById('inv-med-name').readOnly = false;
        document.getElementById('inv-stock').value = inv.stock_quantity;
        document.getElementById('inv-price').value = inv.price;
        document.getElementById('inv-batch').value = inv.batch_number || 'B001';
        document.getElementById('inv-expiry').value = inv.expiry_date;
        document.getElementById('inv-presc-req').checked = !!inv.is_prescription_required;
    } else {
        title.textContent = "Add Stock Item";
        document.getElementById('inventory-id').value = "";
        document.getElementById('inv-med-name').readOnly = false;
    }
    modal.classList.remove('hidden');
}

function editInventory(id) {
    const inv = state.inventory.find(i => i.id === id);
    if (inv) showInventoryModal(inv);
}

async function deleteInventory(id) {
    if (!confirm("Delete this inventory listing?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/admin/inventory/${id}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshInventory();
    } catch(e) {}
}

async function handleInventorySubmit(e) {
    e.preventDefault();
    const id = document.getElementById('inventory-id').value;
    const pharmacy_id = document.getElementById('inv-pharmacy-id').value;
    const medicine_name = document.getElementById('inv-med-name').value;
    const stock_quantity = parseInt(document.getElementById('inv-stock').value);
    const price = parseFloat(document.getElementById('inv-price').value);
    const batch_number = document.getElementById('inv-batch').value;
    const expiry_date = document.getElementById('inv-expiry').value;
    const is_prescription_required = document.getElementById('inv-presc-req').checked;

    const payload = { pharmacy_id, medicine_name, stock_quantity, price, batch_number, expiry_date, is_prescription_required };
    const url = id ? `${API_BASE}/admin/inventory/${id}` : `${API_BASE}/admin/inventory`;
    const method = id ? 'PATCH' : 'POST';

    try {
        const res = await apiFetch(url, { method, body: JSON.stringify(payload) });
        if ((await res.json()).success) {
            document.getElementById('inventory-modal').classList.add('hidden');
            refreshInventory();
        }
    } catch(err) {}
}

// -------------------------------------------------------------
// PRESCRIPTIONS
// -------------------------------------------------------------
async function refreshPrescriptions() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/prescriptions`);
        const data = await res.json();
        if (data.success) {
            state.prescriptions = data.data || [];
            renderPrescriptions();
        }
    } catch(e) {}
}

function renderPrescriptions() {
    const query = document.getElementById('prescriptions-search').value.toLowerCase();
    const statusFilter = document.getElementById('prescriptions-filter-status').value;

    const filtered = state.prescriptions.filter(p => {
        const matchQuery = !query || p.user_id.includes(query) || (p.extracted_text && p.extracted_text.toLowerCase().includes(query));
        const matchStatus = !statusFilter || p.status === statusFilter;
        return matchQuery && matchStatus;
    });

    const tbody = document.getElementById('prescriptions-table-body');
    tbody.innerHTML = filtered.map(p => {
        const meds = p.medicines.map(m => `• ${m.medicine_name} (${m.quantity})`).join('<br>');
        const date = new Date(p.uploaded_at).toLocaleString();
        
        return `
            <tr>
                <td><small style="color:var(--text-secondary)">${p.user_id}</small></td>
                <td>
                    <a href="${p.image_url}" target="_blank">
                        <img src="${p.image_url}" class="medicine-thumb" style="width: 50px; height: 50px;" onerror="this.src='/uploads/prescription_placeholder.png'">
                    </a>
                </td>
                <td>${meds || '<span style="color:var(--text-secondary)">No text extracted</span>'}</td>
                <td><small>${date}</small></td>
                <td><span class="badge ${p.status === 'processed' ? 'active' : 'inactive'}">${p.status}</span></td>
                <td>
                    <button class="btn-action edit" onclick="togglePrescriptionStatus('${p.id}', '${p.status}')"><i class="fa-solid fa-sync"></i> Toggle Status</button>
                    <button class="btn-action delete" onclick="deletePrescription('${p.id}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
                </td>
            </tr>
        `;
    }).join('');
}

async function togglePrescriptionStatus(id, currentStatus) {
    const nextStatus = currentStatus === 'uploaded' ? 'processed' : 'uploaded';
    try {
        await apiFetch(`${API_BASE}/admin/prescriptions/${id}`, {
            method: 'PATCH',
            body: JSON.stringify({ status: nextStatus })
        });
        refreshPrescriptions();
    } catch(e) {}
}

async function deletePrescription(id) {
    if (!confirm("Are you sure you want to delete this prescription history?")) return;
    try {
        await apiFetch(`${API_BASE}/admin/prescriptions/${id}`, { method: 'DELETE' });
        refreshPrescriptions();
    } catch(e) {}
}

// -------------------------------------------------------------
// CUSTOMER DELIVERIES / ORDERS
// -------------------------------------------------------------
async function refreshOrders() {
    try {
        const res = await apiFetch(`${API_BASE}/admin/orders`);
        const data = await res.json();
        if (data.success) {
            state.orders = data.data || [];
            renderOrders();
        }
    } catch(e) {}
}

function renderOrders() {
    const query = document.getElementById('orders-search').value.toLowerCase();
    const statusFilter = document.getElementById('orders-filter-status').value;

    const filtered = state.orders.filter(o => {
        const orderId = o.id ? String(o.id).toLowerCase() : '';
        const pharmacyName = o.pharmacy_name ? String(o.pharmacy_name).toLowerCase() : '';
        const customerName = o.customer_name ? String(o.customer_name).toLowerCase() : '';
        
        const matchQuery = !query || 
                           orderId.includes(query) || 
                           pharmacyName.includes(query) || 
                           customerName.includes(query);
        const matchStatus = !statusFilter || o.status === statusFilter;
        return matchQuery && matchStatus;
    });

    const tbody = document.getElementById('orders-table-body');
    tbody.innerHTML = filtered.map(o => {
        const meds = Array.isArray(o.medicines) ? o.medicines.join(', ') : 'Prescribed items';
        const orderId = o.id ? String(o.id) : '';
        const shortId = orderId ? orderId.substring(0, 8) : 'N/A';
        const totalPrice = (o.total_price !== null && o.total_price !== undefined) ? Number(o.total_price) : 0.0;
        const formattedPrice = isNaN(totalPrice) ? '0.00' : totalPrice.toFixed(2);
        
        return `
            <tr>
                <td><small style="color:var(--text-secondary)">#${shortId}</small></td>
                <td><strong>${o.customer_name || 'Patient'}</strong><br><small>${o.customer_phone || ''}</small></td>
                <td>${o.pharmacy_name || 'Unknown'}</td>
                <td><small>${meds}</small></td>
                <td>${formattedPrice} EGP</td>
                <td><span class="badge ${o.status === 'delivered' ? 'active' : ''}">${o.status || 'pending'}</span></td>
                <td><span class="badge ${o.payment_status === 'paid' ? 'active' : 'inactive'}">${o.payment_status || 'pending'}</span></td>
                <td>
                    <button class="btn-action edit" onclick="editOrder('${orderId}')"><i class="fa-solid fa-gear"></i> Manage</button>
                    <button class="btn-action delete" onclick="deleteOrder('${orderId}')"><i class="fa-regular fa-trash-can"></i> Delete</button>
                </td>
            </tr>
        `;
    }).join('');
}

function editOrder(orderId) {
    const order = state.orders.find(o => o.id === orderId);
    if (!order) return;

    const modal = document.getElementById('order-modal');
    const orderIdStr = order.id ? String(order.id) : '';
    const shortId = orderIdStr ? orderIdStr.substring(0, 8) : 'N/A';
    
    document.getElementById('order-id-field').value = orderIdStr;
    document.getElementById('order-lbl-id').value = `#${shortId}`;
    document.getElementById('order-edit-price').value = order.total_price || 0.0;
    document.getElementById('order-status-select').value = order.status || 'pending';
    document.getElementById('order-payment-select').value = order.payment_status || 'pending';

    const driverSelect = document.getElementById('order-driver-select');
    driverSelect.innerHTML = `<option value="">None / Unassigned</option>` + 
        state.drivers.map(d => `<option value="${d.id}">${d.name} (${d.phone})</option>`).join('');
    driverSelect.value = order.delivery_person_id || '';

    modal.classList.remove('hidden');
}

async function deleteOrder(orderId) {
    if (!confirm("Are you sure you want to cancel and delete this order permanently?")) return;
    try {
        const res = await apiFetch(`${API_BASE}/admin/orders/${orderId}`, { method: 'DELETE' });
        if ((await res.json()).success) refreshOrders();
    } catch(e) {}
}

async function handleOrderSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('order-id-field').value;
    const total_price = parseFloat(document.getElementById('order-edit-price').value);
    const status = document.getElementById('order-status-select').value;
    const payment_status = document.getElementById('order-payment-select').value;
    const delivery_person_id = document.getElementById('order-driver-select').value;

    try {
        const res = await apiFetch(`${API_BASE}/admin/orders/${id}`, {
            method: 'PATCH',
            body: JSON.stringify({ total_price, status, payment_status, delivery_person_id })
        });
        if ((await res.json()).success) {
            document.getElementById('order-modal').classList.add('hidden');
            refreshOrders();
        }
    } catch(err) {}
}
