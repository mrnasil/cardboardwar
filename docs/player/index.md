# Player Dokümantasyonu

## İçindekiler

### Karakterler

1. [Well Rounded - Dengeli](./well_rounded.md) - Tüm statlar eşit seviyede, başlangıç karakteri
2. [Brawler - Dövüşçü](./brawler.md) - Yüksek hasar ve can, düşük hız
3. [Bunny - Tavşan](./bunny.md) - Yüksek hız, düşük can ve hasar
4. [Cardboard - Karton](./cardboard.md) - Ekstra karton kazanımı ile ekonomi odaklı
5. [Crazy - Çılgın](./crazy.md) - Yüksek hasar, düşük can, agresif karakter
6. [Knight - Şövalye](./knight.md) - Yüksek can ve blok, düşük hız, tank karakter

## Açıklama

Player sistemi, oyuncunun karakterini, hareketini, silahlarını ve ilerlemesini yönetir.

## Karakter Tipleri

- **Balanced**: Dengeli statlar (Well Rounded)
- **Tank**: Yüksek can ve blok (Brawler, Knight)
- **Speed**: Yüksek hız (Bunny)
- **Damage**: Yüksek hasar (Crazy)
- **Economy**: Ekstra kaynak (Cardboard)

## Player Özellikleri

- **Hareket Sistemi**: WASD/Ok tuşları ile hareket
- **Dash Sistemi**: Space tuşu ile hızlı hareket
- **Level Sistemi**: Experience kazanarak level atlama
- **Weapon Sistemi**: Birden fazla silah kullanabilme

## İlgili Dosyalar

- Player Script: `scenes/unit/players/player.gd`
- Player Base: `scenes/unit/unit.gd`
- Global Player: `Global.player` (autoload)

