module Asteroids

import Gloria: onevent!, render!, update!
using Gloria: Gloria, AbstractObject, Audio, Event, Font, Layer, Resources, Scene, Texture, Window,
    add!, kill!, killall!, play!, settimer!,
    isalive, iskey, ispressed, text

using Gloria.Shapes: Line, Point, circle, polygon
using Gloria.Physics: Physical, timeintersects

using Colors: @colorant_str

##################################################
# Types
##################################################

mutable struct Controls <: AbstractObject
    level::Int
    lives::Int
    transition::Bool
    t1::Float64
end
Controls() = Controls(0, 3, false, 0.)

struct Banner <: AbstractObject
    text::String
end
Banner(text, t) = (self = Banner(text); settimer!(window, t, ()->kill!(banner_layer, self)); self)

abstract type AsteroidsObject <: AbstractObject end

mutable struct Player <: AsteroidsObject
    a::Float64
    α::Float64
end

struct Shield <: AsteroidsObject end

struct LaserBeam <: AsteroidsObject end

struct Rock <: AsteroidsObject
    scale::Float64
end

function Physical{Player}(a, α)
    shape = polygon((Point(-15., 0.), Point(-25., 15.), Point(25., 0.), Point(-25., -15.)))
    return Physical(Player(a, α), shape)
end

function Physical{Shield}(t)
    self = Physical(Shield(), circle(Point(0., 0.), 50))
    settimer!(window, t, ()->kill!(object_layer, self))
    return self
end

function Physical{LaserBeam}(t, x, y, vx, vy, θ)
    shape = Point(0., 0.)
    self = Physical(LaserBeam(), shape; x=x, y=y, θ=θ, vx=vx, vy=vy)
    settimer!(window, t, ()->kill!(object_layer, self))
    return self
end
Base.size(::Physical{LaserBeam}) = 25

function Physical{Rock}(scale, x, y, vx, vy, θ, ω)
    n = 12
    shape = polygon([Point((50cos(2π*i/n))*scale, (50sin(2π*i/n)+10randn())*scale) for i in 0:(n-1)])
    return Physical(Rock(scale), shape, x=x, y=y, θ=θ, vx=vx, vy=vy, ω=ω)
end

##################################################
# Events
##################################################

function onevent!(::Controls, e::Event{:key_down})
    iskey(e, "escape") && Gloria.quit!(window, e)
end

function onevent!(self::Controls, e::Event{:key_down}, t, dt)
    self.level == 0 && iskey(e, "space") && nextlevel!(t)
end

function onevent!(self::Physical{Player}, e::Event{:key_down}, t, dt)
    if controls.level > 0 && iskey(e, "space")
        play!(laser_sound, volume=10)
        add!(object_layer, Physical{LaserBeam}(t + 1, self.x, self.y, self.vx + cosd(self.θ)*500, self.vy + sind(self.θ)*500, self.θ))
    end
end

function onevent!(self::Physical{Player}, e::Event{:key_up})
    if iskey(e, "right") || iskey(e, "left")
        self.ω = 0.
    end
end

##################################################
# Update
##################################################

function update!(self::Controls, t, dt)
    if self.level > 0 && count(x->x isa Physical{Rock}, object_layer) == 0
        if !self.transition
            settimer!(window, t + 1, ()->(nextlevel!(t+1); self.transition = false))
            self.transition = true
        end
    end
    if self.lives < 0 && !self.transition
        gameover!(t)
        self.transition = true
    end
end

function update!(self::Physical{Player}, t, dt)
    if ispressed(keyboard, "up")
        self.vx += self.wrapped.a*cosd(self.θ)*dt
        self.vy += self.wrapped.a*sind(self.θ)*dt
    end
    if ispressed(keyboard, "left") && abs(self.ω) < 360
        self.ω -= self.wrapped.α*dt
    end
    if ispressed(keyboard, "right") && abs(self.ω) < 360
        self.ω += self.wrapped.α*dt
    end

    for rock in filter(obj -> obj isa Physical{Rock} && isalive(object_layer, obj) && timeintersects(self, obj), object_layer)
        destroyrock!(rock, self)

        if !any(x->x isa Physical{Shield}, object_layer)
            self.x, self.y = 0., 0.
            self.vx, self.vy = 0., 0.
            controls.lives -= 1
            if controls.lives >= 0
                add!(object_layer, Physical{Shield}(t + 2))
            end
        end
    end
end

function update!(self::Physical{Shield}, t, dt)
    self.x = player.x
    self.y = player.y

    for rock in filter(obj -> obj isa Physical{Rock} && isalive(object_layer, obj) && timeintersects(self, obj), object_layer)
        destroyrock!(rock, self)
    end
end

function update!(self::Physical{LaserBeam}, t, dt)
    for rock in filter(obj -> obj isa Physical{Rock} && isalive(object_layer, obj) && timeintersects(self, obj), object_layer)
        kill!(object_layer, self)
        destroyrock!(rock, self)
    end
end

function Gloria.after_update!(self::Physical{<:AsteroidsObject}, t, dt)
    self.x > width/2  + size(self) && (self.x -= width + 2size(self))
    self.x < -width/2 - size(self) && (self.x += width + 2size(self))
    self.y > height/2 + size(self) && (self.y -= height + 2size(self))
    self.y < -height/2 - size(self) && (self.y += height + 2size(self))
end

##################################################
# Render
##################################################

function render!(layer::Layer, self::Banner, frame::Int, fps::Float64)
    render!(layer, text(font_noto, self.text, color=colorant"#FFFFFF", halign=0.5, valign=0.5), 0., 0., 0.)
end

function render!(layer::Layer, self::Controls, frame::Int, fps::Float64)
    if self.level > 0 && self.lives >= 0
        render!(layer, text(font_noto, "Lives: $(self.lives)", color=colorant"#FFFFFF"), 0., 0., 0.)
    elseif self.level == 0
        render!(layer, text(font_noto, "Welcome to Asteroids!", color=colorant"#FFFFFF", halign=0.5, valign=0.5), width/2, height/2 - 50, 0.)
        if (frame % 50) <= 25
            render!(layer, text(font_noto, "Press space to start", color=colorant"#FFFFFF", halign=0.5, valign=0.5), width/2, height/2 + 50, 0.)
        end
    end
end

function render!(layer::Layer, self::Physical{<:Union{LaserBeam,Player,Shield}}, frame::Int, fps::Float64)
    render!(layer, self.shape, self.x, self.y, self.θ, color=colorant"#C0C0C0")
end

function render!(layer::Layer, self::Physical{Rock}, frame::Int, fps::Float64)
    render!(layer, self.shape, self.x, self.y, self.θ, color=colorant"#A0A0A0")
end

##################################################
# Helper functions
##################################################

function startgame!(t)
    killall!(object_layer)
    controls.transition = false
    controls.level = 0
    controls.lives = 3
    player.ω = 0
    player.θ = -90

    add!(object_layer, player, Physical{Shield}(t + 3))
end

function addrock!(scale, v)
    horv = rand(Bool)
    rock = Physical{Rock}(scale,
                          horv ? rand(-width/2:width/2) : rand([-width/2, width/2]),
                          horv ? rand([-height/2, height/2]) : rand(-height/2:height/2),
                          (0.5-randn())*v, (0.5-randn())*v, 360rand(), 90rand())
    add!(object_layer, rock)
end

function destroyrock!(rock, other)
    if isalive(object_layer, rock)
        kill!(object_layer, rock)
        if rock.scale > 0.25
            for _ in 1:2
                vx = 0.1other.vx/rock.scale + rock.vx
                vy = 0.1other.vy/rock.scale + rock.vy
                ω = rock.ω + 50*(rand() - 0.5)
                add!(object_layer, Physical{Rock}(
                    rock.scale/2,
                    rock.x + 25rock.scale*randn(),
                    rock.y + 25rock.scale*randn(),
                    vx, vy, 360rand(), ω))
            end
        end
    end
end

function nextlevel!(t)
    # Reset the current level
    for obj in filter(obj -> obj isa Physical{LaserBeam} || obj isa Physical{Rock}, object_layer)
        kill!(object_layer, obj)
    end

    # Initialize the next level
    controls.level += 1
    level = controls.level
    player.x, player.y = 0., 0.
    player.vx, player.vy = 0., 0.
    player.ω = 0

    add!(banner_layer, Banner("Level $level", t + 1))
    add!(object_layer, Physical{Shield}(t + 2))

    # Populate with rocks!
    if level % 5 == 0
        for _ in 1:level
            addrock!(0.7, 30 + 7level)
        end
    elseif level % 3 != 0
        for _ in 1:level
            addrock!(1., 30 + 5level)
        end
    elseif level % 15 == 0
        for _ in 1:5*level
            addrock!(0.10, 30 + 2level)
        end
    elseif level % 6 != 0
        for _ in 1:3*level
            addrock!(0.25, 30 + 10level)
        end
    else
        for _ in 1:level/3
            addrock!(2.0, 30 + 5level)
        end
    end
end

function gameover!(t)
    kill!(object_layer, player)
    add!(banner_layer, Banner("Game over", t + 3))
    settimer!(window, t + 3, ()->startgame!(t + 3))
end

##################################################
# Setup
##################################################

# const width, height = 1920, 1080
const width, height = 800, 600
const wrap_width, wrap_height = width + 100, height + 100

const controls = Controls()
const controls_layer = Layer([controls])
const banner_layer = Layer(Banner[], width/2, height/2)
const object_layer = Layer(Physical[], width/2, height/2)

const scene = Scene(object_layer, banner_layer, controls_layer, color=colorant"#202020")
const window = Window("Asteroids", width, height, scene, fullscreen=false)

const resources = Resources(window)
const keyboard = Gloria.KeyboardState()

const laser_sound = Audio(resources, abspath(@__DIR__, "..", "assets", "laser.wav"))
const font_noto = Font(resources, abspath(@__DIR__, "..", "assets", "NotoSans-Black.ttf"), fontsize=24)

const player = Physical{Player}(100., 360.)

function main(; keepalive=true)
    Gloria.run!(window)
    startgame!(0)
    if keepalive
        wait(window)
    end
end

##################################################
# Precompile
##################################################

# const dir = abspath(@__DIR__, "..", "precompile")
# const blacklist_import = []
# const fnames = collect(filter(x->occursin(r"^precompile_.*\.jl$", x), readdir(dir)))
# const names = (fname->Symbol(match(r"^precompile_(.*)\.jl$", fname)[1])).(fnames)
# for name in names
#     name in blacklist_import && continue
#     try
#         @eval import $name
#     catch e
#         @warn "Failed import of: $name ($e)"
#     end
# end
# for fname in fnames
#     try
#         include(joinpath(dir, fname))
#         _precompile_()
#         catch e
#         @warn "Failed additional precompilation of: $fname ($e)"
#     end
# end

end # module
