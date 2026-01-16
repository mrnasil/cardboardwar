# Wanderer (Gezgin)

## Genel Bilgiler

**İsim**: Wanderer  
**Tip**: Wanderer (Gezgin)  
**Davranış**: Random haritada yürür

## Tags

- `enemy`
- `wanderer`
- `passive`
- `non-aggressive`

## Stats

| Özellik | Değer |
|---------|-------|
| **Can** | 8 |
| **Hasar** | 2 |
| **Hız** | 200 pixel/s |
| **Blok Şansı** | 3% |

## Açıklama

Player'a saldırmayan pasif düşman. Random haritada yürür ve sadece savunma yapar.

## Davranış

- Random haritada yürür
- Her 2 saniyede yeni random hedef seçer
- Player'a saldırmaz
- Player'a çarparsa hasar verir

## Özellikler

- **Wander Duration**: 2.0 saniye (hedef değiştirme süresi)
- **Wander Target**: Harita sınırları içinde random pozisyon

## Dosya Konumları

- **Scene**: `res://scenes/unit/enemy/enemy_wanderer.tscn`
- **Stats**: `res://resources/unit/enemies/stats_enemy_chaser_slow.tres` (base stats kullanır)
- **Texture**: `res://assets/sprites/Enemies/Enemy_2.png`

