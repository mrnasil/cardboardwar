# Pistol (Tabanca) Serisi

## Genel Bilgiler

**Tip**: Range  
**Açıklama**: Hızlı ateş eden uzun menzil silahı serisi. Seviye 1-6 arası gelişebilir.

## Tags

- `range`
- `pistol`
- `projectile`
- `fast-fire`
- `long-range`
- `tier-1-6`

## Birleştirme Sistemi

**Mantık**: 2x aynı seviye weapon birleştirilerek bir üst seviyeye dönüşür.

- 2x Seviye 1 → 1x Seviye 2
- 2x Seviye 2 → 1x Seviye 3
- 2x Seviye 3 → 1x Seviye 4
- 2x Seviye 4 → 1x Seviye 5
- 2x Seviye 5 → 1x Seviye 6
- Seviye 6 maksimum seviye

## Seviye İstatistikleri

### Seviye 1 - Tabanca
| Özellik | Değer | Çarpan |
|---------|-------|--------|
| **Hasar** | 5.0 | 1.0x |
| **Accuracy** | 0.95 (95%) | - |
| **Cooldown** | 0.8s | 1.0x |
| **Menzil** | 800.0 pixel | 1.0x |
| **Knockback** | 0.5 | 1.0x |
| **Crit Chance** | 0.05 (5%) | 1.0x |
| **Crit Damage** | 2.0x | 1.0x |
| **Projectile Speed** | 1600.0 pixel/s | 1.0x |
| **Maliyet** | 1 | - |

### Seviye 2-6 (Henüz Eklenmedi)

Tahmini çarpanlar:
- **Hasar**: Her seviyede ~1.4x artış
- **Cooldown**: Her seviyede ~0.85x azalış
- **Menzil**: Her seviyede ~1.1x artış
- **Projectile Speed**: Her seviyede ~1.1x artış
- **Accuracy**: Her seviyede ~0.01 artış (max 1.0)

## Çarpan Tablosu (Seviye 1'e göre)

| Seviye | Hasar | Cooldown | Menzil | Knockback | Projectile Speed | Accuracy |
|--------|-------|----------|--------|-----------|------------------|----------|
| 1 | 1.0x | 1.0x | 1.0x | 1.0x | 1.0x | 0.95 |
| 2 | ~1.4x | ~0.85x | ~1.1x | ~1.1x | ~1.1x | ~0.96 |
| 3 | ~2.0x | ~0.72x | ~1.2x | ~1.2x | ~1.2x | ~0.97 |
| 4 | ~2.8x | ~0.61x | ~1.3x | ~1.3x | ~1.3x | ~0.98 |
| 5 | ~3.9x | ~0.52x | ~1.4x | ~1.4x | ~1.4x | ~0.99 |
| 6 | ~5.5x | ~0.44x | ~1.5x | ~1.5x | ~1.5x | 1.0 |

## Özellikler

- Uzun menzil (800 pixel)
- Hızlı ateş hızı (0.8s cooldown)
- Yüksek isabet oranı (%95)
- Projectile tabanlı hasar

## Projectile

- **Scene**: `res://scenes/weapons/projectiles/bullet.tscn`
- **Hız**: 1600 pixel/saniye (Seviye 1)
- **Görsel**: Sarı projectile sprite

## Dosya Konumları

- **Item Seviye 1**: `res://resources/items/weapons/range/pistol/item_pistol_1.tres`
- **Stats Seviye 1**: `res://resources/items/weapons/range/pistol/stats_pistol_1.tres`
- **Scene**: `res://scenes/weapons/range/weapon_pistol.tscn`
- **Icon**: `res://assets/sprites/Weapons/Icons/weapon_pistol_icon.png`

