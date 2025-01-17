module VectorGraphics

import Gloria: onevent!, render!, update!

using Gloria: Gloria, AbstractObject, Event, Layer, Scene, Texture, Window

using Colors: @colorant_str

struct Controls <: AbstractObject end

mutable struct Object <: AbstractObject
    texture::Texture
    x::Float64
    y::Float64
    vx::Float64
    vy::Float64
    θ::Float64
    ω::Float64
end
Object(fname::String, args...) = Object(Texture(window, fname), args...)

function onevent!(::Controls, ::Val{:mousemotion}, e::Event)
    if Gloria.getmousestate().left
        scene.center_x -= e.rel_x
        scene.center_y -= e.rel_y
    end
end

function onevent!(::Controls, ::Val{:mousebutton_down}, e::Event)
    e.button == 1 && Gloria.setrelative(true)
end

function onevent!(::Controls, ::Val{:mousebutton_up}, e::Event)
    e.button == 1 && Gloria.setrelative(false)
end

function update!(obj::Object; dt, args...)
    obj.θ += obj.ω*dt
    obj.x += obj.vx*dt
    obj.y += obj.vy*dt
    abs(obj.x) > width / 2 && (obj.vx *= -1; obj.ω *= -1; obj.x += obj.vx*dt)
    abs(obj.y) > height / 2 && (obj.vy *= -1; obj.ω *= -1; obj.y += obj.vy*dt)
end

function render!(layer::Layer, obj::Object; args...)
    render!(layer, obj.texture, obj.x, obj.y, angle=obj.θ)
end

# Setup

const width, height = 800, 600
const window = Window{Scene}("Vector Graphics", width, height)
const scene = Scene{Layer}()
const controls_layer = Layer{Object}(obj->0, show=false)
const object_layer = Layer{Object}(obj->obj.x)

push!(controls_layer, Controls())
append!(object_layer, [Object(abspath(@__DIR__, "assets", "sample.svg"),
                              (rand() - 0.5)*width, (rand() - 0.5)*height,
                              (rand() - 0.5)*width, (rand() - 0.5)*height,
                              rand()*360, (rand() - 0.5)*1080) for _ in 1:50])

push!(scene, controls_layer, object_layer)
push!(window, scene)

Gloria.run!(window, target_render_speed = 60.0, target_update_speed = 60.0)
# wait(window)

end # module
