# Splitter (Bölünen)

## Genel Bilgiler

**İsim**: Splitter  
**Tip**: Splitter (Bölünen)  
**Davranış**: Player'a koşar, canı düşünce bölünür

## Tags

- `enemy`
- `splitter`
- `melee`
- `splitting`

## Stats

| Özellik | Değer |
|---------|-------|
| **Can** | 15 |
| **Hasar** | 4 |
| **Hız** | 250 pixel/s |
| **Blok Şansı** | 5% |

## Açıklama

Canı %30'un altına düştüğünde 2 küçük enemy'ye bölünen özel düşman.

## Davranış

- Player'a doğru koşar (Chaser gibi)
- Canı %30'un altına düştüğünde bölünür
- 2 küçük enemy spawn eder
- Bölündüğünde normal ölüm işlemleri yapılmaz (karton/bant düşmez)

## Bölünme Özellikleri

- **Split Threshold**: %30 can
- **Split Count**: 2 küçük enemy
- **Small Enemy Health**: Ana enemy'nin %50'si
- **Small Enemy Scale**: %30 ölçek
- **Small Enemy Type**: Chaser Slow

## Özellikler

- **Can Split**: true
- **Split Health Threshold**: 0.3 (30%)

## Dosya Konumları

- **Scene**: `res://scenes/unit/enemy/enemy_splitter.tscn`
- **Stats**: `res://resources/unit/enemies/stats_enemy_chaser_slow.tres` (base stats kullanır)
- **Texture**: `res://assets/sprites/Enemies/Enemy_3.png`

