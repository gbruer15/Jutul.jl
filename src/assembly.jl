export half_face_flux, half_face_flux!, tp_flux, half_face_flux_kernel
export fapply!

function half_face_flux(mob, p, G)
    flux = similar(p, 2*G.nfaces)
    half_face_flux!(flux, mob, p, G)
    return flux
end

function half_face_flux!(model, flux, mob, p)
    half_face_flux!(flux, mob, p, model.domain.conn_data, model.context, kernel_compatibility(model.context))
end

"Half face flux using standard loop"
function half_face_flux!(flux, mob, p, conn_data, context, ::KernelDisallowed)
    Threads.@threads for i in eachindex(conn_data)
        c = conn_data[i]
        for phaseNo = 1:size(mob, 1)
            @inbounds flux[phaseNo, i] = tp_flux(c.self, c.other, c.T, view(mob, phaseNo, :), p)
        end
    end
end

"Half face flux using kernel (GPU/CPU)"
function half_face_flux!(flux, mob, p, conn_data, context, ::KernelAllowed)
    m = length(conn_data)
    kernel = half_face_flux_kernel(context.device, context.block_size, m)
    event = kernel(flux, mob, p, conn_data, ndrange=m)
    wait(event)
end

@kernel function half_face_flux_kernel(flux, @Const(mob), @Const(p), @Const(fd))
    i = @index(Global, Linear)
    @inbounds flux[i] = tp_flux(fd[i].self, fd[i].other, fd[i].T, mob, p)
end

@inline function tp_flux(c_self::I, c_other::I, t_ij, mob::AbstractArray{R}, p::AbstractArray{R}) where {R<:Real, I<:Integer}
    dp = p[c_self] - value(p[c_other])
    if dp > 0
        m = mob[c_self]
    else
        m = value(mob[c_other])
    end
    return m*t_ij*dp
end

"Apply a function to each element in the fastest possible manner."
function fapply!(out, f, inputs...)
    # Example:
    # x, y, z equal length
    # then fapply!(z, *, x, y) is equal to a parallel call of
    # z .= x.*y
    # If JuliaLang Issue #19777 gets resolved we can get rid of fapply!
    Threads.@threads for i in eachindex(out)
        @inbounds out[i] = f(map((x) -> x[i], inputs)...)
    end
end

function fapply!(out::CuArray, f, inputs...)
    # Specialize fapply for GPU to get automatic kernel computation
    @. out = f(inputs...)
end
