# Shooter (Atıcı)

## Genel Bilgiler

**İsim**: Shooter  
**Tip**: Shooter (Atıcı)  
**Davranış**: Player'a ateş eder

## Tags

- `enemy`
- `shooter`
- `range`
- `projectile`

## Stats

| Özellik | Değer |
|---------|-------|
| **Can** | 10 |
| **Hasar** | 2-3 (projectile) |
| **Hız** | 200 pixel/s |
| **Blok Şansı** | 4% |

## Açıklama

Player'a uzaktan ateş eden düşman. Az hasar verir ama sürekli saldırır.

## Davranış

- Player'a doğru döner ama yaklaşmaz
- 1.5 saniyede bir ateş eder
- Player'dan minimum 200 pixel uzakta durur
- Projectile ile hasar verir

## Özellikler

- **Shoot Cooldown**: 1.5 saniye
- **Projectile Damage**: 2-3 arası random
- **Projectile Speed**: 800 pixel/s
- **Minimum Distance**: 200 pixel

## Dosya Konumları

- **Scene**: `res://scenes/unit/enemy/enemy_shooter.tscn`
- **Stats**: `res://resources/unit/enemies/stats_enemy_shooter.tres`
- **Texture**: `res://assets/sprites/Enemies/Enemy_4.png`

