
using DrWatson
@quickactivate "NIPS_2020_NMUX"

using Plots
using Zygote
using Distributions
pyplot()

meshgrid(x, y) = (repeat(x, outer=length(y)), repeat(y, inner=length(x)))


nacmult(x,w;ϵ=1f-7) = exp(w * log(abs(x + ϵ)))

function npu(x::T, w::T; e::T=T(1e-7)) where T
    r = abs(x) + e
    k = T(x < 0 ? pi : 0.0)
    # if r < e && abs(w) < e
    #     T(1)
    # else
    #     return exp(w * log(r)) * cos(w*k)
    # end
    return exp(w * log(r)) * cos(w*k)
end;


id_mse(x,w) = abs(x - npu(x,w))

dx(x,w) = -Zygote.gradient(x->id_mse(x,w), x)[1]
dw(x,w) = -Zygote.gradient(w->id_mse(x,w), w)[1]

x = -1:0.1:2
w = -1:0.1:2
x,w = meshgrid(x,w)
u = dx.(x,w)
v = dw.(x,w)
r = sqrt.(u.^2 + v.^2) * 10
u = u ./ r
v = v ./ r

# p1 = heatmap(x, w, (x,w)->dx(x,w), clim=(-10,10))
# p2 = heatmap(x, w, (x,w)->dw(x,w), clim=(-10,10))
# plot(p1,p2,size=(1000,500))
plt = heatmap(x, w, id_mse, clim=(0,2), c=:viridis)
quiver!(plt, x, w, quiver=(u,v), c=:white)


function nmu(x::Vector, W::Matrix)
     z = W .* reshape(x,1,:) .+ 1 .- W
    dropdims(prod(z, dims=2), dims=2)
end
nmu(X::Matrix, W::Matrix) = vec(mapslices(x->nmu(x,W), X, dims=1))

function npu(x::Vector{T}, W::Matrix{T}) where T
    r = abs.(x) .+ eps(T)
    k = map(i -> T(i < 0 ? pi : 0.0), x)
    exp.(W * log.(r)) .* cos.(W*k)
end
npu(X::Matrix, W::Matrix) = vec(mapslices(x->npu(x,W), X, dims=1))

batch = 500
X = Array{Float64,2}(undef,2,batch)
X[1,:] .= rand(Uniform(-3,3),batch)
X[2,:] .= rand(Uniform(-0.05,0.05),batch)
# X[1,:] .= rand(Uniform(-3,3),batch)
# X[2,:] .= rand(Uniform(-0.001,0.001), batch)


npuloss(w1,w2) = mean(abs2, npu(X, [w1 w2]) .- X[1,:])
nmuloss(w1,w2) = mean(abs2, nmu(X, [w1 w2]) .- X[1,:])

w1 = -1:0.05:1
w2 = -1:0.05:1
#zlim = clim = (-2,10)
#surface(w1, w2, log ∘ loss)
#surface(w1, w2, log ∘ loss, clim=clim, zlim=zlim)

zlim = clim = (0,10)
zlim = clim = (0,4.2)
p1 = surface(w1, w2, (w1,w2)->min(nmuloss(w1,w2), clim[2]), xlabel="w1", ylabel="w2")
zlim = clim = (0,4.2)
p2 = surface(w1, w2, (w1,w2)->min(npuloss(w1,w2), clim[2]), xlabel="w1", ylabel="w2")
plot(p1,p2)

