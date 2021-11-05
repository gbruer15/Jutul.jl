export TimestepSelector, IterationTimestepSelector

abstract type AbstractTimestepSelector end

pick_first_timestep(sel, sim, config, dT) = min(dT*initial_relative(sel), initial_absolute(sel))
pick_next_timestep(sel, sim, config, dt_prev, dT, reports, step_index, new_step) = dt_prev
function pick_cut_timestep(sel, sim, config, dt, dT, reports, cut_count)
    if cut_count + 1 > config[:max_timestep_cuts]
        dt = NaN
    else
        dt = dt/decrease_factor(sel)
    end
    return dt
end

decrease_factor(sel) = 2.0
increase_factor(sel) = 2.0
initial_relative(sel) = 1.0
initial_absolute(sel) = Inf

struct TimestepSelector <: AbstractTimestepSelector
    init_rel
    init_abs
    decrease
    increase
    function TimestepSelector(factor = 2.0; decrease = nothing, initial_relative = 1.0, initial_absolute = Inf)
        if isnothing(decrease)
            decrease = factor
        end
        new(initial_relative, initial_absolute, factor, decrease)
    end
end

decrease_factor(sel::TimestepSelector) = sel.decrease
increase_factor(sel::TimestepSelector) = sel.increase
initial_relative(sel::TimestepSelector) = sel.init_rel
initial_absolute(sel::TimestepSelector) = sel.init_abs

struct IterationTimestepSelector <: AbstractTimestepSelector
    target
    offset
    function IterationTimestepSelector(target_its = 5; offset = 1)
        @assert offset > 0
        new(target_its, offset)
    end
end

function pick_next_timestep(sel::IterationTimestepSelector, sim, config, dt_prev, dT, reports, step_index, new_step)
    if new_step
        R = reports[step_index-1]
    else
        R = reports[step_index]
    end
    r = R[:ministeps][end]
    # Previous number of iterations
    its_p = length(r[:steps]) - 1
    # Target
    its_t, ϵ = sel.target, sel.offset
    # Assume relationship between its and dt is linear (lol)
    return dt_prev*(its_t + ϵ)/(its_p + ϵ)
end