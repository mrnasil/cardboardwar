# Weapon Dokümantasyonu

## İçindekiler

### Melee Silahlar

1. [Punch (Yumruk) Serisi](./punch.md) - Seviye 1-6, tüm seviyeler ve çarpanlar
2. [Knife (Bıçak) Serisi](./knife.md) - Seviye 1-6, tüm seviyeler ve çarpanlar

### Range Silahlar

3. [Pistol (Tabanca) Serisi](./pistol.md) - Seviye 1-6, tüm seviyeler ve çarpanlar

## Açıklama

Weapon sistemi, oyuncunun kullanabileceği silahları yönetir. İki tip silah vardır: Melee (yakın dövüş) ve Range (uzun menzil).

## Weapon Tipleri

- **Melee**: Yakın dövüş silahları (yumruk, bıçak)
- **Range**: Uzun menzil silahları (tabanca)

## Upgrade Sistemi

Tüm silahlar 1-6 seviyeye kadar gelişebilir. Aynı seviyedeki 2 silah birleştirilerek bir üst seviyeye dönüşür:

**Birleştirme Mantığı:**
- 2x Seviye 1 → 1x Seviye 2
- 2x Seviye 2 → 1x Seviye 3
- 2x Seviye 3 → 1x Seviye 4
- 2x Seviye 4 → 1x Seviye 5
- 2x Seviye 5 → 1x Seviye 6

**Örnek:**
- 2x Punch 1 → 1x Punch 2
- 2x Punch 2 → 1x Punch 3
- 2x Punch 3 → 1x Punch 4
- 2x Punch 4 → 1x Punch 5
- 2x Punch 5 → 1x Punch 6

**Not:** Seviye 6 maksimum seviyedir, daha fazla upgrade edilemez.

## İlgili Dosyalar

- Weapon Resource: `resources/items/weapons/item_weapon.gd`
- Weapon Stats: `resources/items/weapons/weapon_stats.gd`
- Melee Behavior: `scenes/weapons/melee/melee_behavior.gd`
- Range Behavior: `scenes/weapons/range/range_behavior.gd`

