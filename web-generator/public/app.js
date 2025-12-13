// State management
const state = {
    mode: 'text',
    uploadedImage: null,
    generateCount: 2,
    selectedModel: 'gemini-2.5-flash',
    isGenerating: false,
    generatedImages: [],
    // Sprite settings
    spriteType: 'player',
    spriteSize: 32,
    animationType: 'single',
    spriteFrame: 'idle',
    frameCount: 6,
    pixelArt: true,
    createSpriteSheet: true,
    saveToAssets: false
};

// DOM Elements
const elements = {
    apiStatus: document.getElementById('apiStatus'),
    statusDot: document.querySelector('.status-dot'),
    statusText: document.querySelector('.status-text'),
    textMode: document.getElementById('textMode'),
    imageMode: document.getElementById('imageMode'),
    spriteMode: document.getElementById('spriteMode'),
    spriteSection: document.getElementById('spriteSection'),
    spriteType: document.getElementById('spriteType'),
    animationType: document.getElementById('animationType'),
    spriteFrame: document.getElementById('spriteFrame'),
    frameCount: document.getElementById('frameCount'),
    singleFrameSection: document.getElementById('singleFrameSection'),
    animationSetSection: document.getElementById('animationSetSection'),
    pixelArt: document.getElementById('pixelArt'),
    createSpriteSheet: document.getElementById('createSpriteSheet'),
    saveToAssets: document.getElementById('saveToAssets'),
    sizeButtons: document.querySelectorAll('.size-btn'),
    uploadSection: document.getElementById('uploadSection'),
    uploadArea: document.getElementById('uploadArea'),
    imageInput: document.getElementById('imageInput'),
    uploadPreview: document.getElementById('uploadPreview'),
    previewImage: document.getElementById('previewImage'),
    removeImage: document.getElementById('removeImage'),
    promptInput: document.getElementById('promptInput'),
    modelFlash: document.getElementById('modelFlash'),
    modelPro: document.getElementById('modelPro'),
    countButtons: document.querySelectorAll('.count-btn'),
    generateBtn: document.getElementById('generateBtn'),
    resultsPanel: document.getElementById('resultsPanel'),
    resultsGrid: document.getElementById('resultsGrid'),
    clearBtn: document.getElementById('clearBtn'),
    loadingOverlay: document.getElementById('loadingOverlay'),
    imageModal: document.getElementById('imageModal'),
    modalImage: document.getElementById('modalImage'),
    modalClose: document.getElementById('modalClose'),
    downloadBtn: document.getElementById('downloadBtn')
};

// Initialize
function init() {
    checkApiStatus();
    setupEventListeners();
    loadModels();
}

// Check API status
async function checkApiStatus() {
    try {
        const response = await fetch('/api/health');
        const data = await response.json();
        
        if (data.connected) {
            elements.statusDot.classList.add('connected');
            elements.statusDot.classList.remove('disconnected');
            elements.statusText.textContent = 'Bağlı';
        } else {
            elements.statusDot.classList.add('disconnected');
            elements.statusDot.classList.remove('connected');
            elements.statusText.textContent = 'Bağlantı Hatası';
        }
    } catch (error) {
        elements.statusDot.classList.add('disconnected');
        elements.statusDot.classList.remove('connected');
        elements.statusText.textContent = 'Bağlantı Hatası';
    }
}

// Load available models
async function loadModels() {
    try {
        const response = await fetch('/api/models');
        const data = await response.json();
        console.log('Available models:', data.models);
    } catch (error) {
        console.error('Error loading models:', error);
    }
}

// Setup event listeners
function setupEventListeners() {
    // Mode selection
    elements.textMode.addEventListener('click', () => handleModeChange('text'));
    elements.imageMode.addEventListener('click', () => handleModeChange('image'));
    elements.spriteMode.addEventListener('click', () => handleModeChange('sprite'));

    // Sprite settings
    elements.spriteType.addEventListener('change', (e) => {
        state.spriteType = e.target.value;
        updateSpritePrompt();
    });
    elements.animationType.addEventListener('change', (e) => {
        state.animationType = e.target.value;
        if (state.animationType === 'single') {
            elements.singleFrameSection.style.display = 'block';
            elements.animationSetSection.style.display = 'none';
        } else {
            elements.singleFrameSection.style.display = 'none';
            elements.animationSetSection.style.display = 'block';
        }
        updateSpritePrompt();
    });
    elements.spriteFrame.addEventListener('change', (e) => {
        state.spriteFrame = e.target.value;
        updateSpritePrompt();
    });
    elements.frameCount.addEventListener('change', (e) => {
        state.frameCount = parseInt(e.target.value);
    });
    elements.pixelArt.addEventListener('change', (e) => {
        state.pixelArt = e.target.checked;
        updateSpritePrompt();
    });
    elements.createSpriteSheet.addEventListener('change', (e) => {
        state.createSpriteSheet = e.target.checked;
    });
    elements.saveToAssets.addEventListener('change', (e) => {
        state.saveToAssets = e.target.checked;
    });
    elements.sizeButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const size = parseInt(btn.dataset.size);
            state.spriteSize = size;
            elements.sizeButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            updateSpritePrompt();
        });
    });

    // Upload area
    elements.uploadArea.addEventListener('click', () => elements.imageInput.click());
    elements.imageInput.addEventListener('change', handleImageUpload);
    elements.removeImage.addEventListener('click', removeUploadedImage);

    // Drag and drop
    elements.uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        elements.uploadArea.style.borderColor = 'var(--accent-primary)';
    });

    elements.uploadArea.addEventListener('dragleave', () => {
        elements.uploadArea.style.borderColor = 'var(--bg-border)';
    });

    elements.uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        elements.uploadArea.style.borderColor = 'var(--bg-border)';
        const files = e.dataTransfer.files;
        if (files.length > 0 && files[0].type.startsWith('image/')) {
            handleFileSelect(files[0]);
        }
    });

    // Model selection
    elements.modelFlash.addEventListener('click', () => handleModelChange('gemini-2.5-flash'));
    elements.modelPro.addEventListener('click', () => handleModelChange('gemini-3-pro'));

    // Count selection
    elements.countButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const count = parseInt(btn.dataset.count);
            handleCountChange(count);
        });
    });

    // Generate button
    elements.generateBtn.addEventListener('click', handleGenerate);

    // Clear button
    elements.clearBtn.addEventListener('click', clearResults);

    // Modal
    elements.modalClose.addEventListener('click', closeModal);
    elements.imageModal.addEventListener('click', (e) => {
        if (e.target === elements.imageModal) {
            closeModal();
        }
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeModal();
        }
    });
}

// Handle mode change
function handleModeChange(mode) {
    state.mode = mode;
    
    // Reset all mode buttons
    elements.textMode.classList.remove('active');
    elements.imageMode.classList.remove('active');
    elements.spriteMode.classList.remove('active');
    
    // Hide all sections
    elements.uploadSection.style.display = 'none';
    elements.spriteSection.style.display = 'none';
    
    if (mode === 'text') {
        elements.textMode.classList.add('active');
        state.uploadedImage = null;
        elements.promptInput.placeholder = 'Görsel için açıklama yazın...';
    } else if (mode === 'image') {
        elements.imageMode.classList.add('active');
        elements.uploadSection.style.display = 'block';
        elements.promptInput.placeholder = 'Görsel için açıklama yazın...';
    } else if (mode === 'sprite') {
        elements.spriteMode.classList.add('active');
        elements.spriteSection.style.display = 'block';
        elements.promptInput.placeholder = 'Sprite detaylarını yazın (otomatik optimize edilecek)...';
        // Update UI based on current animation type
        if (state.animationType === 'single') {
            elements.singleFrameSection.style.display = 'block';
            elements.animationSetSection.style.display = 'none';
        } else {
            elements.singleFrameSection.style.display = 'none';
            elements.animationSetSection.style.display = 'block';
        }
        updateSpritePrompt();
    }
}

// Update sprite prompt based on settings
function updateSpritePrompt() {
    if (state.mode !== 'sprite') return;
    
    const typeNames = {
        player: 'oyun karakteri',
        enemy: 'düşman karakter',
        weapon: 'silah',
        item: 'eşya',
        coin: 'para/coin'
    };
    
    const frameNames = {
        idle: 'bekleme pozisyonunda',
        walk: 'yürüme animasyonunda',
        attack: 'saldırı animasyonunda',
        jump: 'zıplama animasyonunda',
        hurt: 'yaralanma animasyonunda',
        death: 'ölüm animasyonunda',
        punch: 'yumruk animasyonunda',
        turn: 'dönüş animasyonunda',
        air_attack: 'havada saldırı animasyonunda'
    };
    
    const style = state.pixelArt ? 'pixel art stili, retro oyun grafiği' : 'modern oyun grafiği';
    
    let frameDesc = '';
    if (state.animationType === 'single') {
        frameDesc = frameNames[state.spriteFrame] || 'bekleme pozisyonunda';
    } else {
        frameDesc = frameNames[state.animationType] || 'animasyon';
    }
    
    const basePrompt = `${typeNames[state.spriteType]}, ${frameDesc}, ${state.spriteSize}x${state.spriteSize} piksel, ${style}, şeffaf arka plan, game sprite, side view, 2D game asset`;
    
    // If user has custom prompt, append to it, otherwise set as base
    const currentPrompt = elements.promptInput.value.trim();
    if (!currentPrompt || currentPrompt.startsWith(typeNames[state.spriteType])) {
        elements.promptInput.value = basePrompt;
    }
}

// Handle image upload
function handleImageUpload(e) {
    const file = e.target.files[0];
    if (file) {
        handleFileSelect(file);
    }
}

function handleFileSelect(file) {
    if (file.size > 10 * 1024 * 1024) {
        alert('Dosya boyutu 10MB\'dan büyük olamaz');
        return;
    }

    state.uploadedImage = file;
    
    const reader = new FileReader();
    reader.onload = (e) => {
        elements.previewImage.src = e.target.result;
        elements.uploadContent = document.querySelector('.upload-content');
        if (elements.uploadContent) {
            elements.uploadContent.style.display = 'none';
        }
        elements.uploadPreview.style.display = 'block';
    };
    reader.readAsDataURL(file);
}

function removeUploadedImage() {
    state.uploadedImage = null;
    elements.imageInput.value = '';
    elements.uploadPreview.style.display = 'none';
    const uploadContent = document.querySelector('.upload-content');
    if (uploadContent) {
        uploadContent.style.display = 'flex';
    }
}

// Handle model change
function handleModelChange(model) {
    state.selectedModel = model;
    
    if (model === 'gemini-2.5-flash') {
        elements.modelFlash.classList.add('active');
        elements.modelPro.classList.remove('active');
    } else {
        elements.modelFlash.classList.remove('active');
        elements.modelPro.classList.add('active');
    }
}

// Handle count change
function handleCountChange(count) {
    state.generateCount = count;
    
    elements.countButtons.forEach(btn => {
        if (parseInt(btn.dataset.count) === count) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
}

// Handle generate
async function handleGenerate() {
    if (state.isGenerating) return;

    let prompt = elements.promptInput.value.trim();
    
    // For sprite mode, ensure prompt is optimized
    if (state.mode === 'sprite') {
        updateSpritePrompt();
        prompt = elements.promptInput.value.trim();
        // Ensure transparent background is mentioned
        if (!prompt.toLowerCase().includes('transparent') && !prompt.toLowerCase().includes('şeffaf')) {
            prompt += ', transparent background, no background';
        }
    }
    
    if (!prompt) {
        alert('Lütfen bir prompt girin');
        return;
    }

    if (state.mode === 'image' && !state.uploadedImage) {
        alert('Lütfen bir referans görsel yükleyin');
        return;
    }

    state.isGenerating = true;
    elements.generateBtn.disabled = true;
    elements.loadingOverlay.style.display = 'flex';

    try {
        const formData = new FormData();
        formData.append('prompt', prompt);
        formData.append('model', state.selectedModel);
        
        // Determine count based on animation type
        let generateCount = state.generateCount;
        if (state.mode === 'sprite' && state.animationType !== 'single') {
            generateCount = state.frameCount; // Use frame count for animation sets
        }
        formData.append('count', generateCount);
        
        // Add sprite mode info if applicable
        if (state.mode === 'sprite') {
            formData.append('spriteMode', 'true');
            formData.append('spriteType', state.spriteType);
            formData.append('spriteSize', state.spriteSize);
            formData.append('animationType', state.animationType);
            if (state.animationType === 'single') {
                formData.append('spriteFrame', state.spriteFrame);
            } else {
                formData.append('spriteFrame', state.animationType); // Use animation type as frame
            }
            formData.append('frameCount', state.frameCount);
            formData.append('pixelArt', state.pixelArt);
            formData.append('createSpriteSheet', state.createSpriteSheet);
            formData.append('saveToAssets', state.saveToAssets);
        }
        
        if (state.uploadedImage) {
            formData.append('image', state.uploadedImage);
        }

        const response = await fetch('/api/generate', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Görsel üretilemedi');
        }

        displayResults(data.images, data.savedFiles, data.isAnimationSet, data.spriteSize, data.createSpriteSheet);
    } catch (error) {
        console.error('Generate error:', error);
        alert('Hata: ' + error.message);
    } finally {
        state.isGenerating = false;
        elements.generateBtn.disabled = false;
        elements.loadingOverlay.style.display = 'none';
    }
}

// Create sprite sheet on frontend
function createSpriteSheetFrontend(imageBase64Array, spriteSize, frameCount) {
    const frameWidth = spriteSize;
    const frameHeight = spriteSize;
    const cols = Math.min(frameCount, 4); // Max 4 columns
    const rows = Math.ceil(frameCount / cols);
    
    const sheetWidth = frameWidth * cols;
    const sheetHeight = frameHeight * rows;
    
    const canvas = document.createElement('canvas');
    canvas.width = sheetWidth;
    canvas.height = sheetHeight;
    const ctx = canvas.getContext('2d');
    
    // Make background transparent
    ctx.clearRect(0, 0, sheetWidth, sheetHeight);
    
    // Load and draw each frame
    return Promise.all(imageBase64Array.map((imageBase64, index) => {
        return new Promise((resolve) => {
            const col = index % cols;
            const row = Math.floor(index / cols);
            const x = col * frameWidth;
            const y = row * frameHeight;
            
            const img = new Image();
            img.onload = () => {
                ctx.drawImage(img, x, y, frameWidth, frameHeight);
                resolve();
            };
            img.onerror = () => resolve(); // Continue even if one frame fails
            img.src = `data:image/png;base64,${imageBase64}`;
        });
    })).then(() => {
        return canvas.toDataURL('image/png').split(',')[1]; // Return base64 without data URL prefix
    });
}

// Display results
function displayResults(images, savedFiles = null, isAnimationSet = false, spriteSize = 32, createSpriteSheet = false) {
    state.generatedImages = images;
    
    if (images.length === 0) {
        elements.resultsGrid.innerHTML = `
            <div class="empty-state">
                <p>Görsel üretilemedi</p>
            </div>
        `;
        return;
    }

    let html = '';

    // Create and add sprite sheet if requested
    if (isAnimationSet && createSpriteSheet && images.length > 1) {
        createSpriteSheetFrontend(images, spriteSize, images.length).then(spriteSheetBase64 => {
            const spriteSheetItem = document.querySelector('.sprite-sheet-item');
            if (spriteSheetItem) {
                const img = spriteSheetItem.querySelector('img');
                if (img) {
                    img.src = `data:image/png;base64,${spriteSheetBase64}`;
                }
            }
        }).catch(error => {
            console.error('Sprite sheet oluşturma hatası:', error);
        });
        
        html += `
            <div class="result-item sprite-sheet-item" data-sprite-sheet="">
                <div class="sprite-sheet-header">
                    <h4>Sprite Sheet</h4>
                    <button class="play-animation-btn" data-frames='${JSON.stringify(images)}'>▶ Oynat</button>
                </div>
                <div class="sprite-sheet-loading">Oluşturuluyor...</div>
                <img src="" alt="Sprite Sheet" style="display: none;">
            </div>
        `;
    }

    // Add animation preview if animation set
    if (isAnimationSet && images.length > 1) {
        html += `
            <div class="result-item animation-preview-item">
                <div class="animation-preview-header">
                    <h4>Animasyon Önizleme</h4>
                    <button class="play-animation-btn active" data-frames='${JSON.stringify(images)}'>⏸ Durdur</button>
                </div>
                <canvas id="animationCanvas" width="${state.spriteSize * 4}" height="${state.spriteSize * 4}"></canvas>
            </div>
        `;
    }

    // Add individual frames
    html += images.map((imageBase64, index) => {
        const savedFile = savedFiles && savedFiles[index] ? savedFiles[index] : null;
        const savedBadge = savedFile ? `
            <div class="saved-badge">
                <span>✓ Kaydedildi</span>
                <small>${savedFile.relativePath}</small>
            </div>
        ` : '';
        
        const frameLabel = isAnimationSet ? `<div class="frame-label">Frame ${index + 1}</div>` : '';
        
        return `
            <div class="result-item" data-image-index="${index}" data-image-base64="${imageBase64}">
                ${frameLabel}
                <div class="result-item-overlay">
                    <button class="remove-bg-btn" data-image-index="${index}" data-image-base64="${imageBase64}">
                        <span class="btn-icon">✂️</span>
                        <span class="btn-text">Arka Planı Sil</span>
                    </button>
                </div>
                <img src="data:image/png;base64,${imageBase64}" alt="Generated ${index + 1}">
                ${savedBadge}
            </div>
        `;
    }).join('');

    elements.resultsGrid.innerHTML = html;

    // Setup animation preview
    if (isAnimationSet && images.length > 1) {
        setupAnimationPreview(images, spriteSize);
    }

    // Add click listeners to result items
    elements.resultsGrid.querySelectorAll('.result-item:not(.animation-preview-item)').forEach(item => {
        item.addEventListener('click', () => {
            const imageBase64 = item.dataset.imageBase64 || item.dataset.spriteSheet;
            if (imageBase64) {
                const index = parseInt(item.dataset.imageIndex) || 0;
                openModal(imageBase64, index);
            }
        });
    });

    // Add play animation button listeners
    elements.resultsGrid.querySelectorAll('.play-animation-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const frames = JSON.parse(btn.dataset.frames);
            toggleAnimation(frames, btn);
        });
    });

    // Add remove background button listeners
    elements.resultsGrid.querySelectorAll('.remove-bg-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const imageBase64 = btn.dataset.imageBase64;
            const imageIndex = parseInt(btn.dataset.imageIndex);
            await handleRemoveBackground(imageBase64, imageIndex, btn);
        });
    });

    // Scroll to results
    if (elements.resultsPanel) {
        elements.resultsPanel.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

// Setup animation preview
let animationInterval = null;
function setupAnimationPreview(frames, spriteSize = 32) {
    const canvas = document.getElementById('animationCanvas');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    let currentFrame = 0;
    const frameSize = spriteSize * 4; // Scale up for preview
    
    canvas.width = frameSize;
    canvas.height = frameSize;
    
    // Enable pixelated rendering for pixel art
    ctx.imageSmoothingEnabled = false;
    
    function drawFrame() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const img = new Image();
        img.onload = () => {
            ctx.drawImage(img, 0, 0, frameSize, frameSize);
        };
        img.src = `data:image/png;base64,${frames[currentFrame]}`;
        currentFrame = (currentFrame + 1) % frames.length;
    }
    
    // Start animation
    drawFrame();
    animationInterval = setInterval(drawFrame, 200); // 200ms per frame
}

function toggleAnimation(frames, button) {
    if (animationInterval) {
        clearInterval(animationInterval);
        animationInterval = null;
        button.textContent = '▶ Oynat';
        button.classList.remove('active');
    } else {
        const canvas = document.getElementById('animationCanvas');
        if (canvas) {
            setupAnimationPreview(frames);
            button.textContent = '⏸ Durdur';
            button.classList.add('active');
        }
    }
}

// Handle remove background
async function handleRemoveBackground(imageBase64, imageIndex, button) {
    // Disable button and show loading
    button.disabled = true;
    const originalText = button.innerHTML;
    button.innerHTML = '<span class="btn-icon">⏳</span><span class="btn-text">Siliniyor...</span>';
    
    try {
        const response = await fetch('/api/remove-background', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ imageBase64 })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Arka plan silinemedi');
        }

        // Debug: Check if the returned image is different from original
        const originalBase64 = imageBase64;
        const newBase64 = data.imageBase64;
        const isDifferent = originalBase64 !== newBase64;
        console.log('Arka plan silme sonucu:', {
            originalLength: originalBase64.length,
            newLength: newBase64.length,
            isDifferent: isDifferent,
            first100Original: originalBase64.substring(0, 100),
            first100New: newBase64.substring(0, 100)
        });

        if (!isDifferent) {
            console.warn('UYARI: Arka plan silme API\'si orijinal görseli döndürdü!');
        }

        // Get the original result item
        const originalResultItem = button.closest('.result-item');
        const originalSavedFile = originalResultItem.querySelector('.saved-badge');
        const savedFileHTML = originalSavedFile ? originalSavedFile.outerHTML : '';
        const frameLabel = originalResultItem.querySelector('.frame-label');
        
        // Check if this is an animation set
        const isAnimationSet = originalResultItem.dataset.imageIndex !== undefined;
        
        // Create a new result item for the background-removed image
        const newResultItem = document.createElement('div');
        newResultItem.className = 'result-item';
        newResultItem.dataset.imageIndex = `${imageIndex}-no-bg`;
        newResultItem.dataset.imageBase64 = data.imageBase64;
        
        // Add frame label if exists
        if (frameLabel) {
            const newFrameLabel = frameLabel.cloneNode(true);
            const frameText = newFrameLabel.textContent;
            newFrameLabel.textContent = frameText.replace('Frame', 'Frame (Arka Plan Silindi)');
            newResultItem.appendChild(newFrameLabel);
        }
        
        // Add the image
        const img = document.createElement('img');
        img.src = `data:image/png;base64,${data.imageBase64}`;
        img.alt = `Generated ${imageIndex + 1} (Arka Plan Silindi)`;
        newResultItem.appendChild(img);
        
        // Add saved badge if exists
        if (savedFileHTML) {
            newResultItem.insertAdjacentHTML('beforeend', savedFileHTML);
        }
        
        // Add a badge to indicate this is the background-removed version
        const noBgBadge = document.createElement('div');
        noBgBadge.className = 'no-bg-badge';
        noBgBadge.innerHTML = '<span>✓ Arka Plan Silindi</span>';
        newResultItem.appendChild(noBgBadge);
        
        // Add click listener for modal
        newResultItem.addEventListener('click', () => {
            openModal(data.imageBase64, `${imageIndex}-no-bg`);
        });
        
        // Insert the new item right after the original item
        originalResultItem.insertAdjacentElement('afterend', newResultItem);
        
        // Update button to show success and disable it
        button.innerHTML = '<span class="btn-icon">✓</span><span class="btn-text">Silindi</span>';
        button.classList.add('success');
        button.disabled = true; // Keep disabled since we now have a separate item
        
        // Scroll to the new item
        newResultItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        
    } catch (error) {
        console.error('Arka plan silme hatası:', error);
        alert('Arka plan silinirken hata oluştu: ' + error.message);
        
        // Restore button
        button.disabled = false;
        button.innerHTML = originalText;
    }
}

// Clear results
function clearResults() {
    state.generatedImages = [];
    elements.resultsGrid.innerHTML = `
        <div class="empty-state">
            <p>Henüz görsel üretilmedi</p>
        </div>
    `;
}

// Open modal
function openModal(imageBase64, index) {
    elements.modalImage.src = `data:image/png;base64,${imageBase64}`;
    elements.downloadBtn.href = `data:image/png;base64,${imageBase64}`;
    elements.downloadBtn.download = `generated-image-${index + 1}.png`;
    elements.imageModal.style.display = 'flex';
}

// Close modal
function closeModal() {
    elements.imageModal.style.display = 'none';
}

// Make openModal available globally (for backwards compatibility)
window.openModal = openModal;

// Initialize on page load
document.addEventListener('DOMContentLoaded', init);

