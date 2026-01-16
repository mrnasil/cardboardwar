# Enemy Dokümantasyonu

## İçindekiler

### Chaser (Kovalayan) Düşmanlar

1. [Chaser Slow - Yavaş Kovalayan](./chaser_slow.md) - Yavaş hareket eden temel düşman
2. [Chaser Mid - Orta Hızlı Kovalayan](./chaser_mid.md) - Orta hızda hareket eden düşman
3. [Chaser Fast - Hızlı Kovalayan](./chaser_fast.md) - Hızlı hareket eden tehlikeli düşman
4. [Charger - Şarj Eden](./charger.md) - Yüksek hızda player'a şarj eden güçlü düşman

### Özel Davranışlı Düşmanlar

5. [Wanderer - Gezgin](./wanderer.md) - Random haritada yürür, player'a saldırmaz
6. [Shooter - Atıcı](./shooter.md) - Player'a uzaktan ateş eder
7. [Splitter - Bölünen](./splitter.md) - Canı düşünce 2 küçük enemy'ye bölünür

## Açıklama

Enemy sistemi, oyundaki düşmanların davranışlarını ve özelliklerini yönetir. Farklı davranış tiplerine sahip düşmanlar vardır.

## Enemy Davranış Tipleri

- **CHASER**: Player'a doğru koşar
- **WANDERER**: Random haritada yürür
- **SHOOTER**: Player'a ateş eder
- **SPLITTER**: Canı düşünce bölünür

## İlgili Dosyalar

- Enemy Script: `scenes/unit/enemy/enemy.gd`
- Enemy Manager: `autoloads/enemy_manager.gd`
- Spawn Manager: `autoloads/spawn_manager.gd`

