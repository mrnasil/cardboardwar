# Chaser Slow (Yavaş Kovalayan)

## Genel Bilgiler

**İsim**: ChaserSlow  
**Tip**: Chaser (Kovalayan)  
**Davranış**: Player'a doğru koşar

## Tags

- `enemy`
- `chaser`
- `slow`
- `melee`

## Stats

| Özellik | Değer |
|---------|-------|
| **Can** | 6 |
| **Hasar** | 2 |
| **Hız** | 248 pixel/s |
| **Blok Şansı** | 3% |

## Açıklama

Yavaş hareket eden temel düşman. Player'a doğru koşar ve yakın mesafede hasar verir.

## Davranış

- Player'a doğru sürekli hareket eder
- Player'a 100 pixel'den yaklaşmaz (bug önleme)
- Flock push ile diğer enemy'lerden uzaklaşır
- Vision area ile yakındaki enemy'leri algılar

## Ölüm Sonrası

- Karton (Cardboard) düşer
- %20 şansla Bant (Tape) düşer
- Player'a 1-3 experience verir

## Dosya Konumları

- **Scene**: `res://scenes/unit/enemy/enemy_chaser_slow.tscn`
- **Stats**: `res://resources/unit/enemies/stats_enemy_chaser_slow.tres`
- **Texture**: `res://assets/sprites/Enemies/Enemy_1.png`

