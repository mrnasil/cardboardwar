Godot 4.5.1 - 2D Oyunlar İçin Gelişmiş Performans Optimizasyon İpuçları ve En İyi Uygulamalar (Brotato Benzeri Dahil)
Bu doküman, Godot 4.5.1'de sadece 2D oyunlar için kapsamlı optimizasyon rehberidir. Resmi belgeler, forumlar, Reddit ve topluluk devlog'larından (2025 itibarıyla) derlenmiştir. 4.5'te TileMap physics chunking varsayılan etkin, rendering quadrant iyileşmiş ve navigation async gibi yenilikler roguelite'lerde faydalı. Profilleyin: Godot Profiler, Time.get_ticks_usec(), collision pairs monitor edin. Binary search ile darboğaz bulun.
1. Performansı Ölçme ve Darboğaz Analizi

























Araç2D Roguelite İpucuGodot ProfilerPhysics > Collision Pairs izleyin (10k+ spike = darboğaz).Manuel TimingBullet/enemy loop'ları time edin.GPU TestiFill rate + draw calls (Rendering > Draw Calls).PlatformMobil: Compatibility, Web: WASM SIMD.
2. CPU Optimizasyonu

Node Pooling: 1000+ bullet/enemy için reuse.gdscriptvar pool: Array[RigidBody2D] = []
func get_enemy() -> RigidBody2D:
    if pool.size(): return pool.pop_back()
    return preload("enemy.tscn").instantiate()
Flat Hierarchy + Top_level=true.
C# DOD: Arrays ile position/velocity yönet (cache friendly).

3. GPU / Rendering (Canvas Batching)

Atlas + same material için batching max.
Transparency minimize.

4. TileMap Optimizasyonları

Physics chunking ON (büyük arena için).

5. 4.5 Özellikleri

Async nav regions.

6. En İyi Uygulamalar

Async load, mobil test.

7. Brotato Benzeri Roguelite Shooter İçin Özgü Optimizasyonlar
Brotato/Vampire Survivors: 100s enemy, 1000s bullet, waves, items, particles. Node'lar yetmez; DOD + servers kullanın (10k+ entity).
7.1 Yüksek Entity Yönetimi
Teknik,Açıklama,Kazanç
Object Pooling,"Pre-instantiate, reuse (enemies/bullets/items). Cap active (örn. 500 enemy).",5-10x CPU.
DOD/ECS,"Single manager: var positions: PackedVector2Array, bulk update. C# tercih.",10k+ entity 60FPS.
Staggered Spawn/Update,"Waves'i frame'lere yay, groups update (örn. 1/10 enemy/frame).",Spike önle.

7.2 Rendering (Bullet Hell)

RenderingServer2D: Single CanvasItem + _draw ile 2.5k+ bullet 240FPS.gdscript# BulletManager extends Node2D
var bullets: Array[Bullet] = []
class Bullet: refcounted:
    var pos: Vector2; var frame: int
func _draw():
    for b in bullets: draw_texture(frames[b.frame], b.pos)
func _physics_process(delta):
    for b in bullets: b.pos += velocity * delta  # update
    queue_redraw()
BlastBullets2D Plugin: C++ MultiMesh2D, pooling, collision signals. Asset Lib'den indir.
Atlas animasyon.

7.3 Physics/Collision

PhysicsServer2D: Shared Area2D + dynamic shapes (RID'ler).
Layers/Masks: Bullet vs Hurtbox only, enemy-enemy off. Disable distant/off-screen.
Pairs <5k tutun.

7.4 AI ve Pathfinding

Flow/Vector Field: Prebake map, sample direction (no A*).
LOD AI: Uzak: simple seek; yakın: full.

7.5 Particles/Effects

Pool emitters, GPUParticles2D ama CPU fallback. Viewport visibility off.

7.6 Wave ve Arena

Staggered spawn (0.1s delay).
Culling: VisibleOnScreenNotifier + distance delete.
Coord shift: Büyük arena için origin reset.

Kazanç Örneği: Node'lar 80FPS -> Servers/DOD 240+FPS (2.5k bullet).
Sonuç
Brotato benzeri için servers + DOD ile 60+FPS garantili. Profilleyin! Docs.