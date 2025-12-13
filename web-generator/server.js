require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { Client } = require('@gradio/client');

const app = express();
const PORT = process.env.PORT || 3000;
const PROXY_URL = process.env.VERTEX_PROXY_URL;
const API_KEY = process.env.VERTEX_API_KEY;
const ASSETS_PATH = path.join(__dirname, '..', 'Assets');

// Log storage for API access
const logStorage = [];
const MAX_LOG_LINES = 500; // Keep last 500 lines

// Override console.log to capture logs
const originalConsoleLog = console.log;
console.log = function(...args) {
  const timestamp = new Date().toISOString();
  const message = args.map(arg => 
    typeof arg === 'object' ? JSON.stringify(arg, null, 2) : String(arg)
  ).join(' ');
  
  logStorage.push({ timestamp, message });
  if (logStorage.length > MAX_LOG_LINES) {
    logStorage.shift(); // Remove oldest log
  }
  
  originalConsoleLog.apply(console, args);
};

// Also capture console.error
const originalConsoleError = console.error;
console.error = function(...args) {
  const timestamp = new Date().toISOString();
  const message = 'ERROR: ' + args.map(arg => 
    typeof arg === 'object' ? JSON.stringify(arg, null, 2) : String(arg)
  ).join(' ');
  
  logStorage.push({ timestamp, message });
  if (logStorage.length > MAX_LOG_LINES) {
    logStorage.shift();
  }
  
  originalConsoleError.apply(console, args);
};

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Increase limit for base64 images
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));

// Multer configuration
const upload = multer({
  dest: 'uploads/',
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB
});

// Ensure uploads directory exists
if (!fs.existsSync('uploads')) {
  fs.mkdirSync('uploads');
}

// Ensure Assets directory exists
if (!fs.existsSync(ASSETS_PATH)) {
  fs.mkdirSync(ASSETS_PATH, { recursive: true });
}

// Available models
const AVAILABLE_MODELS = {
  'gemini-2.5-flash': {
    id: 'gemini-2.5-flash-image-preview',
    name: 'Gemini 2.5 Flash',
    description: 'Hızlı görsel üretimi',
    speed: 'Hızlı',
    quality: 'İyi'
  },
  'gemini-3-pro': {
    id: 'gemini-3-pro-image-preview',
    name: 'Gemini 3 Pro',
    description: 'Yüksek kaliteli görsel üretimi',
    speed: 'Yavaş',
    quality: 'Mükemmel'
  }
};

// Optimize prompt for sprite generation
function optimizeSpritePrompt(prompt, spriteType, spriteSize, spriteFrame, pixelArt) {
  const typeNames = {
    player: 'oyun karakteri, player character',
    enemy: 'düşman karakter, enemy character',
    weapon: 'silah, weapon',
    item: 'eşya, item, power-up',
    coin: 'para, coin, collectible'
  };
  
  const frameNames = {
    idle: 'bekleme pozisyonunda, idle animation frame',
    walk: 'yürüme animasyonunda, walking animation frame',
    attack: 'saldırı animasyonunda, attack animation frame',
    jump: 'zıplama animasyonunda, jump animation frame',
    hurt: 'yaralanma animasyonunda, hurt animation frame',
    death: 'ölüm animasyonunda, death animation frame',
    punch: 'yumruk animasyonunda, punch animation frame',
    turn: 'dönüş animasyonunda, turn around animation frame',
    air_attack: 'havada saldırı animasyonunda, air attack animation frame'
  };
  
  const style = pixelArt 
    ? 'pixel art style, retro game graphics, 8-bit style, low resolution, sharp pixels, no anti-aliasing'
    : 'modern game graphics, smooth rendering';
  
  // Request transparent background - user can remove manually if needed
  const background = 'transparent background, no background, alpha channel';
  
  const optimizedPrompt = `${typeNames[spriteType] || 'game sprite'}, ${frameNames[spriteFrame] || 'idle'}, ${spriteSize}x${spriteSize} pixels, ${style}, ${background}, PNG format, game sprite, side view, 2D game asset, centered. ${prompt}`;
  
  return optimizedPrompt;
}

// Note: Sprite sheet creation is done on the frontend using HTML5 Canvas
// This keeps the server lightweight and avoids native dependencies

// Save sprite to Assets folder
function saveSpriteToAssets(imageBase64, spriteType, spriteSize, spriteFrame, index = 0) {
  const typeFolders = {
    player: 'Players',
    enemy: 'Enemies',
    weapon: 'Player Weapons',
    item: 'Items',
    coin: '' // Coin goes directly to Assets root
  };
  
  const folder = typeFolders[spriteType] || 'Sprites';
  const spritePath = folder ? path.join(ASSETS_PATH, folder) : ASSETS_PATH;
  
  // Ensure folder exists
  if (!fs.existsSync(spritePath)) {
    fs.mkdirSync(spritePath, { recursive: true });
  }
  
  // Generate filename
  const timestamp = Date.now();
  const filename = `${spriteType}_${spriteFrame}_${spriteSize}_${timestamp}_${index}.png`;
  const filePath = path.join(spritePath, filename);
  
  // Convert base64 to buffer and save
  const imageBuffer = Buffer.from(imageBase64, 'base64');
  fs.writeFileSync(filePath, imageBuffer);
  
  // Calculate relative path for display
  const relativePath = folder 
    ? path.join(folder, filename).replace(/\\/g, '/') 
    : filename;
  
  return {
    path: filePath,
    relativePath: relativePath,
    filename: filename
  };
}

// Remove background using Gradio Client
async function removeBackground(imageBase64) {
  try {
    console.log('Arka plan silme başlatılıyor (Gradio Client)...');
    console.log('Görsel boyutu:', (imageBase64.length * 3) / 4 / 1024, 'KB (base64)');
    
    // Convert base64 to Buffer
    const imageBuffer = Buffer.from(imageBase64, 'base64');
    console.log('Buffer boyutu:', imageBuffer.length / 1024, 'KB');
    
    // Create a Blob-like object for Gradio client
    // Gradio client might expect File or Blob, but Buffer should also work
    // If it doesn't work, we'll try converting to a File-like object
    
    // Connect to Gradio client with timeout
    console.log('Gradio client\'a bağlanılıyor...');
    const client = await Promise.race([
      Client.connect("innoai/Background-Remover-Gradio5"),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Gradio client bağlantı timeout')), 30000)
      )
    ]);
    
    console.log('Gradio client bağlantısı başarılı');
    
    // Get available endpoints
    try {
      const apiInfo = await client.view_api();
      console.log('Mevcut API endpoint\'leri:', JSON.stringify(apiInfo, null, 2).substring(0, 1000));
    } catch (apiError) {
      console.log('API bilgisi alınamadı:', apiError.message);
    }
    
    // Call the predict function with the image
    // The endpoint is "/remove_background" and it expects a Blob/File/Buffer
    console.log('Arka plan silme isteği gönderiliyor...');
    const result = await Promise.race([
      client.predict("/remove_background", {
        image: imageBuffer
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Gradio API timeout (60s)')), 60000)
      )
    ]);
    
    console.log('Gradio API yanıtı alındı');
    console.log('Yanıt tipi:', typeof result);
    console.log('Yanıt constructor:', result ? result.constructor.name : 'null');
    console.log('Yanıt isArray:', Array.isArray(result));
    
    // Log full result structure (first 3000 chars to see structure)
    try {
      const resultStr = JSON.stringify(result, null, 2);
      console.log('Yanıt (ilk 3000 karakter):', resultStr.substring(0, 3000));
      if (resultStr.length > 3000) {
        console.log('... (toplam', resultStr.length, 'karakter)');
      }
    } catch (e) {
      console.log('Yanıt JSON.stringify edilemedi:', e.message);
      console.log('Yanıt toString:', result ? result.toString() : 'null');
    }
    
    if (result && typeof result === 'object') {
      console.log('Yanıt keys:', Object.keys(result));
    }
    
    // Check if result is directly an array
    let outputImage = null;
    
    // Try 1: Direct array
    if (Array.isArray(result)) {
      console.log('✓ Yanıt doğrudan array formatında, uzunluk:', result.length);
      if (result.length > 0) {
        outputImage = result[0];
        console.log('  İlk eleman tipi:', typeof outputImage);
      }
    }
    // Try 2: result.data as array
    else if (result && result.data && Array.isArray(result.data)) {
      console.log('✓ Yanıt result.data array formatında, uzunluk:', result.data.length);
      if (result.data.length > 0) {
        const firstItem = result.data[0];
        console.log('  İlk eleman tipi:', typeof firstItem);
        
        // Check if first item is an object with url field (Gradio FileData format)
        if (firstItem && typeof firstItem === 'object' && firstItem.url) {
          console.log('  İlk eleman object ve url field\'ı var:', firstItem.url);
          // Download image from URL
          try {
            const imageResponse = await axios.get(firstItem.url, { responseType: 'arraybuffer' });
            const base64Data = Buffer.from(imageResponse.data).toString('base64');
            console.log('  URL\'den görsel indirildi, base64 uzunluğu:', base64Data.length);
            outputImage = base64Data;
          } catch (urlError) {
            console.error('  URL\'den görsel indirilemedi:', urlError.message);
            // Try second element if available (might contain base64 in HTML)
            if (result.data.length > 1 && typeof result.data[1] === 'string') {
              console.log('  İkinci eleman string, base64 araması yapılıyor...');
              const secondItem = result.data[1];
              // Try to extract base64 from HTML string
              const base64Match = secondItem.match(/base64,([A-Za-z0-9+/=]+)/);
              if (base64Match && base64Match[1]) {
                outputImage = base64Match[1];
                console.log('  İkinci elemandan base64 çıkarıldı');
              }
            }
          }
        } else if (typeof firstItem === 'string') {
          outputImage = firstItem;
        } else {
          // Try to find url in the object
          if (firstItem && typeof firstItem === 'object') {
            console.log('  Object keys:', Object.keys(firstItem));
            if (firstItem.path) {
              // Try to construct URL from path
              const gradioUrl = `https://innoai-background-remover-gradio5.hf.space/gradio_api/file=${firstItem.path}`;
              console.log('  path field\'ından URL oluşturuldu:', gradioUrl);
              try {
                const imageResponse = await axios.get(gradioUrl, { responseType: 'arraybuffer' });
                const base64Data = Buffer.from(imageResponse.data).toString('base64');
                outputImage = base64Data;
                console.log('  path URL\'den görsel indirildi');
              } catch (pathError) {
                console.error('  path URL\'den görsel indirilemedi:', pathError.message);
              }
            }
          }
        }
        
        // If still no image found, try second element (might contain base64 in HTML)
        if (!outputImage && result.data.length > 1 && typeof result.data[1] === 'string') {
          console.log('  İlk elemandan görsel bulunamadı, ikinci eleman kontrol ediliyor...');
          const secondItem = result.data[1];
          // Try to extract base64 from HTML string
          const base64Match = secondItem.match(/base64,([A-Za-z0-9+/=]+)/);
          if (base64Match && base64Match[1]) {
            outputImage = base64Match[1];
            console.log('  ✓ İkinci elemandan base64 çıkarıldı');
          } else {
            console.log('  İkinci elemandan base64 çıkarılamadı');
          }
        }
      }
    }
    // Try 3: result.data as string
    else if (result && result.data && typeof result.data === 'string') {
      console.log('✓ Yanıt result.data string formatında');
      outputImage = result.data;
    }
    // Try 4: result as object - search for image/output keys
    else if (result && typeof result === 'object' && !Array.isArray(result)) {
      console.log('Yanıt object formatında, tüm keys:', Object.keys(result));
      
      // Search for common image-related keys
      const imageKeys = ['image', 'output', 'result', 'data', 'file', 'url', 'base64'];
      for (const key of Object.keys(result)) {
        const lowerKey = key.toLowerCase();
        console.log(`  ${key}:`, typeof result[key], Array.isArray(result[key]) ? `array[${result[key]?.length}]` : '');
        
        if (imageKeys.some(ik => lowerKey.includes(ik))) {
          if (Array.isArray(result[key]) && result[key].length > 0) {
            outputImage = result[key][0];
            console.log(`  ✓ Bulunan görsel key: ${key}[0]`);
            break;
          } else if (typeof result[key] === 'string') {
            outputImage = result[key];
            console.log(`  ✓ Bulunan görsel key: ${key}`);
            break;
          }
        }
      }
      
      // If still not found, try first string value
      if (!outputImage) {
        for (const key of Object.keys(result)) {
          if (typeof result[key] === 'string' && result[key].length > 100) {
            outputImage = result[key];
            console.log(`  ✓ İlk uzun string değer bulundu: ${key}`);
            break;
          }
        }
      }
    }
    
    if (outputImage) {
      console.log('✓ Output image bulundu!');
      console.log('  Tip:', typeof outputImage);
      console.log('  Uzunluk:', typeof outputImage === 'string' ? outputImage.length : 'N/A');
      if (typeof outputImage === 'string') {
        console.log('  İlk 150 karakter:', outputImage.substring(0, 150));
      }
    } else {
      console.error('✗ Output image bulunamadı!');
    }
    
    if (outputImage && typeof outputImage === 'string') {
      console.log('Output image tipi:', typeof outputImage);
      console.log('Output image uzunluğu:', outputImage.length);
      console.log('Output image ilk 100 karakter:', outputImage.substring(0, 100));
      // Extract base64 from data URL if present
      if (outputImage.includes('data:image')) {
        const base64Data = outputImage.split(',')[1];
        console.log('Arka plan başarıyla silindi (data URL formatı)');
        console.log('Yeni görsel boyutu:', (base64Data.length * 3) / 4 / 1024, 'KB (base64)');
        
        // Verify the result is different from input
        if (base64Data === imageBase64) {
          console.warn('UYARI: API orijinal görseli döndürdü!');
          throw new Error('Arka plan silme başarısız: API orijinal görseli döndürdü');
        }
        
        return base64Data;
      } else if (outputImage.startsWith('http')) {
        // URL formatında dönebilir, fetch etmemiz gerekebilir
        console.log('Görsel URL formatında:', outputImage);
        const imageResponse = await axios.get(outputImage, { responseType: 'arraybuffer' });
        const base64Data = Buffer.from(imageResponse.data).toString('base64');
        console.log('Arka plan başarıyla silindi (URL\'den indirildi)');
        
        // Verify the result is different from input
        if (base64Data === imageBase64) {
          console.warn('UYARI: API orijinal görseli döndürdü!');
          throw new Error('Arka plan silme başarısız: API orijinal görseli döndürdü');
        }
        
        return base64Data;
      } else {
        // Already base64 string
        console.log('Arka plan başarıyla silindi (direkt base64)');
        
        // Verify the result is different from input
        if (outputImage === imageBase64) {
          console.warn('UYARI: API orijinal görseli döndürdü!');
          throw new Error('Arka plan silme başarısız: API orijinal görseli döndürdü');
        }
        
        return outputImage;
      }
    }
    
    // If outputImage is not found or not a string, log full result
    console.error('Beklenmeyen yanıt formatı - outputImage bulunamadı');
    console.error('Tam yanıt:', JSON.stringify(result, null, 2));
    throw new Error('Gradio API beklenmeyen yanıt formatı: Görsel bulunamadı');
  } catch (error) {
    console.error('Background removal error:', {
      message: error.message,
      name: error.name,
      stack: error.stack?.substring(0, 1000)
    });
    // Don't return original image - throw error instead
    throw error;
  }
}

// Generate image function
async function generateImage(prompt, referenceImage, modelKey, spriteOptions = null) {
  const model = AVAILABLE_MODELS[modelKey];
  if (!model) {
    throw new Error('Geçersiz model');
  }

  const endpoint = `${PROXY_URL}/v1/projects/test/locations/global/publishers/google/models/${model.id}:generateContent`;

  const parts = [];
  
  // Add reference image if provided
  if (referenceImage) {
    const imageBuffer = fs.readFileSync(referenceImage.path);
    const imageBase64 = imageBuffer.toString('base64');
    const mimeType = referenceImage.mimetype || 'image/jpeg';
    
    parts.push({
      inline_data: {
        mime_type: mimeType,
        data: imageBase64
      }
    });
  }

  // Optimize prompt for sprites if sprite mode is active
  let finalPrompt = prompt;
  if (spriteOptions) {
    finalPrompt = optimizeSpritePrompt(
      prompt,
      spriteOptions.type,
      spriteOptions.size,
      spriteOptions.frame,
      spriteOptions.pixelArt
    );
  }

  // Add prompt
  parts.push({
    text: finalPrompt
  });

  const requestData = {
    contents: [{
      role: "user",
      parts: parts
    }],
    generationConfig: {
      temperature: 1.0,
      topP: 0.95
    },
    safetySettings: [
      { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" }
    ]
  };

  try {
    const response = await axios.post(endpoint, requestData, {
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': API_KEY
      },
      timeout: 300000
    });

    // Extract image from response
    if (response.data.candidates && response.data.candidates[0]) {
      const imagePart = response.data.candidates[0].content.parts.find(p => p.inlineData);
      if (imagePart && imagePart.inlineData) {
        return imagePart.inlineData.data;
      }
    }
    
    throw new Error('Görsel bulunamadı');
  } catch (error) {
    console.error('API Error:', error.response?.data || error.message);
    throw error;
  }
}

// Routes
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    connected: !!API_KEY && !!PROXY_URL,
    timestamp: new Date().toISOString()
  });
});

app.get('/api/logs', (req, res) => {
  const lines = parseInt(req.query.lines) || 100; // Default 100 lines
  const filteredLogs = logStorage.slice(-lines); // Get last N lines
  
  res.json({
    total: logStorage.length,
    requested: lines,
    returned: filteredLogs.length,
    logs: filteredLogs
  });
});

app.get('/api/models', (req, res) => {
  res.json({
    models: Object.keys(AVAILABLE_MODELS).map(key => ({
      key,
      ...AVAILABLE_MODELS[key]
    }))
  });
});

// Remove background endpoint - called manually by user
app.post('/api/remove-background', async (req, res) => {
  try {
    const { imageBase64 } = req.body;
    
    if (!imageBase64) {
      return res.status(400).json({ error: 'Görsel gerekli' });
    }
    
    console.log('Manuel arka plan silme isteği alındı');
    console.log('Base64 uzunluğu:', imageBase64.length);
    
    const result = await removeBackground(imageBase64);
    
    res.json({ 
      success: true,
      imageBase64: result
    });
  } catch (error) {
    console.error('Arka plan silme hatası:', error);
    res.status(500).json({ 
      error: error.message || 'Arka plan silinirken hata oluştu'
    });
  }
});

app.post('/api/generate', upload.single('image'), async (req, res) => {
  try {
    const { prompt, model, count, spriteMode, spriteType, spriteSize, animationType, spriteFrame, frameCount, pixelArt, createSpriteSheet, saveToAssets } = req.body;
    
    if (!prompt) {
      return res.status(400).json({ error: 'Prompt gerekli' });
    }

    if (!model || !AVAILABLE_MODELS[model]) {
      return res.status(400).json({ error: 'Geçersiz model' });
    }

    let generateCount = parseInt(count) || 1;
    
    // For animation sets, allow more frames
    const isAnimationSet = spriteMode === 'true' && animationType !== 'single';
    if (isAnimationSet) {
      const maxFrames = parseInt(frameCount) || 6;
      generateCount = Math.min(maxFrames, 12); // Max 12 frames
    } else if (generateCount < 1 || generateCount > 4) {
      return res.status(400).json({ error: 'Varyasyon sayısı 1-4 arası olmalı' });
    }

    const referenceImage = req.file || null;
    
    // Prepare sprite options if sprite mode is active
    const spriteOptions = spriteMode === 'true' ? {
      type: spriteType || 'player',
      size: parseInt(spriteSize) || 32,
      frame: animationType === 'single' ? (spriteFrame || 'idle') : (animationType || 'idle'),
      pixelArt: pixelArt === 'true' || pixelArt === true
    } : null;

    // Generate images in parallel
    const promises = Array(generateCount).fill(null).map((_, index) => 
      generateImage(prompt, referenceImage, model, spriteOptions).then(imageBase64 => ({
        imageBase64,
        index
      }))
    );

    const results = await Promise.allSettled(promises);
    
    let images = results
      .filter(result => result.status === 'fulfilled')
      .map(result => result.value);

    // Background removal is now done manually via button click

    // Clean up uploaded file
    if (referenceImage) {
      fs.unlinkSync(referenceImage.path);
    }

    if (images.length === 0) {
      return res.status(500).json({ error: 'Görsel üretilemedi' });
    }

    // Sprite sheet will be created on the frontend
    // We just pass the flag and frame count

    // Save to Assets folder if requested and sprite mode is active
    const savedFiles = [];
    if (saveToAssets === 'true' && spriteOptions) {
      // Save individual frames
      images.forEach(({ imageBase64, index }) => {
        try {
          const saved = saveSpriteToAssets(
            imageBase64,
            spriteOptions.type,
            spriteOptions.size,
            spriteOptions.frame,
            index
          );
          savedFiles.push(saved);
        } catch (error) {
          console.error('Error saving sprite to Assets:', error);
        }
      });
      
      // Sprite sheet saving will be handled on frontend if needed
    }

    res.json({ 
      images: images.map(img => img.imageBase64),
      savedFiles: savedFiles.length > 0 ? savedFiles : undefined,
      isAnimationSet: isAnimationSet || false,
      spriteSize: spriteOptions ? spriteOptions.size : undefined,
      createSpriteSheet: createSpriteSheet === 'true'
    });
  } catch (error) {
    console.error('Generate error:', error);
    
    // Clean up uploaded file on error
    if (req.file) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({ 
      error: error.message || 'Görsel üretilirken hata oluştu' 
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server çalışıyor: http://localhost:${PORT}`);
  console.log(`API Key: ${API_KEY ? '✓ Yapılandırılmış' : '✗ Eksik'}`);
  console.log(`Proxy URL: ${PROXY_URL || '✗ Eksik'}`);
});

