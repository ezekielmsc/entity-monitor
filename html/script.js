let currentStats = null;
let autoRefreshEnabled = false;
let sortBy = 'total';
let debugModeEnabled = false;

// Toggle interface
function toggleMonitor(show) {
    const container = document.getElementById('monitorApp');
    if (show) {
        container.classList.add('active');
        container.style.display = 'flex';
    } else {
        container.classList.remove('active');
        container.style.display = 'none';
    }
}

// Format numbers
function formatNumber(num) {
    return num.toLocaleString('fr-FR');
}

// Get usage class based on entity count
function getUsageClass(total, maxTotal) {
    const percentage = (total / maxTotal) * 100;
    if (percentage > 30) return 'high-usage';
    if (percentage > 15) return 'medium-usage';
    return '';
}

// Get rank badge class
function getRankBadgeClass(rank) {
    if (rank === 1) return 'rank-1';
    if (rank === 2) return 'rank-2';
    if (rank === 3) return 'rank-3';
    return 'rank-other';
}

// Update stats display
function updateStats(stats) {
    currentStats = stats;

    // Update totals (utiliser les stats serveur)
    const totals = stats.totals || { vehicles: 0, peds: 0, objects: 0 };

    document.getElementById('totalVehicles').textContent = formatNumber(totals.vehicles || 0);
    document.getElementById('totalPeds').textContent = formatNumber(totals.peds || 0);
    document.getElementById('totalObjects').textContent = formatNumber(totals.objects || 0);
    document.getElementById('totalEntities').textContent = formatNumber(totals.total || 0);

    // Update server info
    if (stats.serverInfo) {
        document.getElementById('playerCount').textContent =
            `${stats.serverInfo.players || 0}/${stats.serverInfo.maxPlayers || 32}`;
        document.getElementById('resourceCount').textContent =
            `${(stats.serverInfo.resources || []).length} ressources`;
    }

    // Update last update time
    const now = new Date();
    document.getElementById('lastUpdate').innerHTML =
        `<i class="fas fa-clock"></i><span>Derniere MAJ: ${now.toLocaleTimeString('fr-FR')}</span>`;

    // Display resources
    displayResources(stats);
}

// Display resources list
function displayResources(stats) {
    const container = document.getElementById('resourcesList');
    container.innerHTML = '';

    // Utiliser directement les ressources triées du serveur
    let resources = stats.sortedResources || [];

    // Sort resources
    resources.sort((a, b) => {
        switch (sortBy) {
            case 'vehicles': return b.vehicles - a.vehicles;
            case 'peds': return b.peds - a.peds;
            case 'objects': return b.objects - a.objects;
            default: return b.total - a.total;
        }
    });

    // Check if no resources with entities
    if (resources.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-check-circle"></i>
                <h3>Aucune entite detectee</h3>
                <p>Toutes les ressources sont propres</p>
            </div>
        `;
        return;
    }

    // Find max total for percentage calculations
    const maxTotal = resources.length > 0 ? resources[0].total : 1;

    // Create resource items
    resources.forEach((resource, index) => {
        const usageClass = getUsageClass(resource.total, maxTotal);
        const rankClass = getRankBadgeClass(index + 1);

        const vehiclePercent = resource.total > 0 ? (resource.vehicles / resource.total) * 100 : 0;
        const pedPercent = resource.total > 0 ? (resource.peds / resource.total) * 100 : 0;
        const objectPercent = resource.total > 0 ? (resource.objects / resource.total) * 100 : 0;

        const item = document.createElement('div');
        item.className = `resource-item ${usageClass}`;
        item.style.animationDelay = `${index * 0.05}s`;

        item.innerHTML = `
            <div class="resource-header">
                <div class="resource-name">
                    <span class="rank-badge ${rankClass}">${index + 1}</span>
                    <i class="fas fa-puzzle-piece"></i>
                    ${resource.name}
                </div>
                <div class="resource-total">${formatNumber(resource.total)}</div>
            </div>
            <div class="resource-stats">
                <div class="resource-stat vehicles">
                    <i class="fas fa-car"></i>
                    <span>${formatNumber(resource.vehicles)}</span>
                </div>
                <div class="resource-stat peds">
                    <i class="fas fa-user"></i>
                    <span>${formatNumber(resource.peds)}</span>
                </div>
                <div class="resource-stat objects">
                    <i class="fas fa-cube"></i>
                    <span>${formatNumber(resource.objects)}</span>
                </div>
            </div>
            <div class="resource-progress">
                <div class="progress-vehicles" style="width: ${vehiclePercent}%"></div>
                <div class="progress-peds" style="width: ${pedPercent}%"></div>
                <div class="progress-objects" style="width: ${objectPercent}%"></div>
            </div>
        `;

        container.appendChild(item);
    });
}

// Refresh data
function refreshData() {
    const refreshBtn = document.getElementById('refreshBtn');
    refreshBtn.classList.add('refreshing');

    // Show loading state
    document.getElementById('resourcesList').innerHTML = `
        <div class="loading-state">
            <i class="fas fa-spinner fa-spin"></i>
            <p>Chargement des donnees...</p>
        </div>
    `;

    $.post(`https://${GetParentResourceName()}/refresh`);

    setTimeout(() => {
        refreshBtn.classList.remove('refreshing');
    }, 1000);
}

// Toggle auto refresh
function toggleAutoRefresh() {
    autoRefreshEnabled = !autoRefreshEnabled;
    const btn = document.getElementById('autoRefreshBtn');

    if (autoRefreshEnabled) {
        btn.classList.add('active');
        btn.title = 'Auto-refresh: ON';
    } else {
        btn.classList.remove('active');
        btn.title = 'Auto-refresh: OFF';
    }

    $.post(`https://${GetParentResourceName()}/toggleAutoRefresh`, JSON.stringify({
        enabled: autoRefreshEnabled
    }));
}

// Close monitor
function closeMonitor() {
    $.post(`https://${GetParentResourceName()}/close`);
    toggleMonitor(false);
}

// Toggle debug mode
function toggleDebugMode() {
    debugModeEnabled = !debugModeEnabled;
    const btn = document.getElementById('debugBtn');
    const panel = document.getElementById('debugPanel');

    if (debugModeEnabled) {
        btn.classList.add('active');
        panel.style.display = 'block';
    } else {
        btn.classList.remove('active');
        panel.style.display = 'none';
    }

    $.post(`https://${GetParentResourceName()}/toggleDebug`);
}

// Update MLO info
function updateMLOInfo(data) {
    document.getElementById('unknownCount').textContent = data.totalUnknown || 0;
    document.getElementById('mloCount').textContent = (data.mlos || []).length;

    const mloList = document.getElementById('mloList');
    mloList.innerHTML = '';

    if (!data.mlos || data.mlos.length === 0) {
        mloList.innerHTML = `
            <div style="text-align: center; padding: 15px; color: var(--text-secondary);">
                <i class="fas fa-check-circle" style="color: var(--success-green); font-size: 20px; margin-bottom: 8px; display: block;"></i>
                Aucun MLO suspect detecte
            </div>
        `;
        return;
    }

    data.mlos.forEach((mlo, index) => {
        const item = document.createElement('div');
        item.className = 'mlo-item';
        item.innerHTML = `
            <div class="mlo-info">
                <span class="mlo-coords">
                    <i class="fas fa-map-marker-alt"></i>
                    X: ${mlo.coords.x.toFixed(1)} Y: ${mlo.coords.y.toFixed(1)} Z: ${mlo.coords.z.toFixed(1)}
                </span>
                <span class="mlo-count">${mlo.count} entites dans cette zone ${mlo.interior > 0 ? '(Interior: ' + mlo.interior + ')' : ''}</span>
            </div>
            <div class="mlo-actions">
                <button class="mlo-btn" onclick="teleportToMLO(${mlo.coords.x}, ${mlo.coords.y}, ${mlo.coords.z})">
                    <i class="fas fa-location-arrow"></i>
                    TP
                </button>
            </div>
        `;
        mloList.appendChild(item);
    });
}

// Teleport to MLO
function teleportToMLO(x, y, z) {
    $.post(`https://${GetParentResourceName()}/teleportToMLO`, JSON.stringify({
        coords: { x: x, y: y, z: z }
    }));
}

// Analyze problems
function analyzeProblems() {
    const btn = document.getElementById('analyzeBtn');
    btn.classList.add('refreshing');

    $.post(`https://${GetParentResourceName()}/analyzeProblems`, JSON.stringify({}), function(problems) {
        btn.classList.remove('refreshing');
        displayProblems(problems);
        document.getElementById('problemsPanel').style.display = 'block';
    });
}

// Display problems
function displayProblems(problems) {
    // Clothing
    const clothingList = document.getElementById('clothingList');
    const clothingCount = document.getElementById('clothingCount');
    clothingList.innerHTML = '';
    clothingCount.textContent = problems.clothing ? problems.clothing.length : 0;
    clothingCount.className = 'problem-count' + ((problems.clothing && problems.clothing.length > 0) ? '' : ' zero');

    if (problems.clothing && problems.clothing.length > 0) {
        problems.clothing.forEach(item => {
            if (!item.coords) return;
            const div = document.createElement('div');
            div.className = 'problem-item';
            div.innerHTML = `
                <div class="problem-item-info">
                    <span class="problem-item-type">${item.type || 'Accessoire'}</span>
                    <span class="problem-item-details">X: ${item.coords.x ? item.coords.x.toFixed(1) : '?'} Y: ${item.coords.y ? item.coords.y.toFixed(1) : '?'}</span>
                </div>
                <div class="problem-item-actions">
                    <button class="problem-item-btn" onclick="teleportToMLO(${item.coords.x || 0}, ${item.coords.y || 0}, ${item.coords.z || 0})">
                        <i class="fas fa-location-arrow"></i>
                    </button>
                </div>
            `;
            clothingList.appendChild(div);
        });
    } else {
        clothingList.innerHTML = '<div class="problem-empty"><i class="fas fa-check-circle"></i> Aucun prop vetement orphelin</div>';
    }

    // Orphan Vehicles
    const vehiclesList = document.getElementById('orphanVehiclesList');
    const vehiclesCount = document.getElementById('orphanVehiclesCount');
    vehiclesList.innerHTML = '';
    vehiclesCount.textContent = problems.orphanVehicles ? problems.orphanVehicles.length : 0;
    vehiclesCount.className = 'problem-count' + ((problems.orphanVehicles && problems.orphanVehicles.length > 0) ? '' : ' zero');

    if (problems.orphanVehicles && problems.orphanVehicles.length > 0) {
        problems.orphanVehicles.forEach(item => {
            if (!item.coords) return;
            const div = document.createElement('div');
            div.className = 'problem-item';
            div.innerHTML = `
                <div class="problem-item-info">
                    <span class="problem-item-type">${item.model || 'Vehicule'}</span>
                    <span class="problem-item-details">${item.distanceToPlayer ? item.distanceToPlayer.toFixed(0) : '?'}m du joueur le plus proche</span>
                </div>
                <div class="problem-item-actions">
                    <button class="problem-item-btn" onclick="teleportToMLO(${item.coords.x || 0}, ${item.coords.y || 0}, ${item.coords.z || 0})">
                        <i class="fas fa-location-arrow"></i>
                    </button>
                </div>
            `;
            vehiclesList.appendChild(div);
        });
    } else {
        vehiclesList.innerHTML = '<div class="problem-empty"><i class="fas fa-check-circle"></i> Aucun vehicule orphelin</div>';
    }

    // Out of Bounds
    const outOfBoundsList = document.getElementById('outOfBoundsList');
    const outOfBoundsCount = document.getElementById('outOfBoundsCount');
    outOfBoundsList.innerHTML = '';
    outOfBoundsCount.textContent = problems.outOfBounds ? problems.outOfBounds.length : 0;
    outOfBoundsCount.className = 'problem-count' + ((problems.outOfBounds && problems.outOfBounds.length > 0) ? '' : ' zero');

    if (problems.outOfBounds && problems.outOfBounds.length > 0) {
        problems.outOfBounds.forEach(item => {
            if (!item.coords) return;
            const div = document.createElement('div');
            div.className = 'problem-item';
            div.innerHTML = `
                <div class="problem-item-info">
                    <span class="problem-item-type">${item.type} ${item.model || ''}</span>
                    <span class="problem-item-details">Z: ${item.coords.z ? item.coords.z.toFixed(1) : '?'} (hors limites)</span>
                </div>
                <div class="problem-item-actions">
                    <button class="problem-item-btn" onclick="deleteEntity(${item.handle})">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            `;
            outOfBoundsList.appendChild(div);
        });
    } else {
        outOfBoundsList.innerHTML = '<div class="problem-empty"><i class="fas fa-check-circle"></i> Aucune entite hors map</div>';
    }

    // Duplicates
    const duplicatesList = document.getElementById('duplicatesList');
    const duplicatesCount = document.getElementById('duplicatesCount');
    duplicatesList.innerHTML = '';
    duplicatesCount.textContent = problems.duplicates ? problems.duplicates.length : 0;
    duplicatesCount.className = 'problem-count' + ((problems.duplicates && problems.duplicates.length > 0) ? '' : ' zero');

    if (problems.duplicates && problems.duplicates.length > 0) {
        problems.duplicates.forEach(item => {
            if (!item.coords) return;
            const div = document.createElement('div');
            div.className = 'problem-item';
            div.innerHTML = `
                <div class="problem-item-info">
                    <span class="problem-item-type">${item.count || '?'} objets superposes</span>
                    <span class="problem-item-details">X: ${item.coords.x ? item.coords.x.toFixed(1) : '?'} Y: ${item.coords.y ? item.coords.y.toFixed(1) : '?'}</span>
                </div>
                <div class="problem-item-actions">
                    <button class="problem-item-btn" onclick="teleportToMLO(${item.coords.x || 0}, ${item.coords.y || 0}, ${item.coords.z || 0})">
                        <i class="fas fa-location-arrow"></i>
                    </button>
                </div>
            `;
            duplicatesList.appendChild(div);
        });
    } else {
        duplicatesList.innerHTML = '<div class="problem-empty"><i class="fas fa-check-circle"></i> Aucun duplicata detecte</div>';
    }
}

// Clean clothing props
function cleanClothing() {
    $.post(`https://${GetParentResourceName()}/cleanClothing`, JSON.stringify({}), function(result) {
        if (result.cleaned > 0) {
            analyzeProblems(); // Refresh
        }
    });
}

// Delete single entity
function deleteEntity(handle) {
    $.post(`https://${GetParentResourceName()}/deleteEntity`, JSON.stringify({ handle: handle }), function(result) {
        if (result.success) {
            analyzeProblems(); // Refresh
        }
    });
}

// Clean all problems
function cleanAllProblems() {
    cleanClothing();
    // Add other cleanup functions here
}

// Event Listeners
document.getElementById('closeBtn').addEventListener('click', closeMonitor);
document.getElementById('refreshBtn').addEventListener('click', refreshData);
document.getElementById('autoRefreshBtn').addEventListener('click', toggleAutoRefresh);
document.getElementById('debugBtn').addEventListener('click', toggleDebugMode);
document.getElementById('analyzeBtn').addEventListener('click', analyzeProblems);
document.getElementById('cleanClothingBtn').addEventListener('click', cleanClothing);
document.getElementById('cleanAllBtn').addEventListener('click', cleanAllProblems);

document.getElementById('sortBy').addEventListener('change', function(e) {
    sortBy = e.target.value;
    if (currentStats) {
        displayResources(currentStats);
    }
});

// ESC to close
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeMonitor();
    }
});

// Listen to FiveM messages
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'open':
            toggleMonitor(true);
            break;

        case 'close':
            toggleMonitor(false);
            break;

        case 'updateStats':
            updateStats(data.stats);
            break;

        case 'debugModeChanged':
            debugModeEnabled = data.enabled;
            const btn = document.getElementById('debugBtn');
            const panel = document.getElementById('debugPanel');
            if (data.enabled) {
                btn.classList.add('active');
                panel.style.display = 'block';
            } else {
                btn.classList.remove('active');
                panel.style.display = 'none';
            }
            break;

        case 'updateMLOInfo':
            updateMLOInfo(data);
            break;
    }
});

// Initialize
console.log('[EntityMonitor] NUI loaded');
