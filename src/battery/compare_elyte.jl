#=
Compare the simulation of electrolyte in Julia and Matlab
=#

using Terv
using MAT
##

function test_simple_elyte()
    name="modelElectrolyte"
    fn = string(dirname(pathof(Terv)), "/../data/models/", name, ".mat")
    exported = MAT.matread(fn)
    ex_model = exported["model"]
    boundary = ex_model["bcstruct"]["dirichlet"]

    b_phi = boundary["phi"][:, 1]
    b_c = boundary["conc"][:, 1]
    b_faces = Int64.(boundary["faces"])

    T_all = ex_model["operators"]["T_all"]
    N_all = Int64.(ex_model["G"]["faces"]["neighbors"])
    isboundary = (N_all[b_faces, 1].==0) .| (N_all[b_faces, 2].==0)
    @assert all(isboundary)
    bc_cells = N_all[b_faces, 1] + N_all[b_faces, 2]
    b_T_hf   = T_all[b_faces] 

    domain = exported_model_to_domain(ex_model, bc=bc_cells, b_T_hf=b_T_hf)

    timesteps = exported["schedule"]["step"]["val"][:, 1]
    
    G = ex_model["G"]
    sys = SimpleElyte()
    model = SimulationModel(domain, sys, context = DefaultContext())
    parameters = setup_parameters(model)
    parameters[:t] = ex_model["sp"]["t"][1]
    parameters[:z] = ex_model["sp"]["z"][1]

    S = model.secondary_variables
    S[:BoundaryPhi] = BoundaryPotential{Phi}()
    S[:BoundaryC] = BoundaryPotential{C}()

    init_states = exported["state0"]
    init = Dict(
        :Phi            => init_states["phi"][:, 1],
        :C              => init_states["cs"][1][:, 1],
        :T              => init_states["T"][:, 1],
        :BoundaryPhi    => b_phi,
        :BoundaryC      => b_c,
        )

    state0 = setup_state(model, init)
  
    sim = Simulator(model, state0=state0, parameters=parameters)
    cfg = simulator_config(sim)
    cfg[:linear_solver] = nothing
    states = simulate(sim, timesteps, config = cfg)
    return states, G, model
end

states, G, model = test_simple_elyte();

##

f = plot_interactive(G, states)
display(f)
##

accstates = []
for i in 1:18
    state = Dict{Symbol, Any}()
    state[:MassAcc] = (states[i+1][:MassAcc] .- states[i][:MassAcc])
    push!(accstates, state)
end

f = plot_interactive(G, accstates)
display(f)
##

function test_simple_elyte_1d()
    name = "model1d"
    fn = string(dirname(pathof(Terv)), "/../data/models/", name, ".mat")
    exported = MAT.matread(fn)
    ex_model = exported["model"]["Electrolyte"]

    b_faces = [1, 31]
    b_phi = [1., 0]
    b_c = [20., 1]

    T_all = ex_model["operators"]["T_all"]
    N_all = Int64.(ex_model["G"]["faces"]["neighbors"])
    isboundary = (N_all[b_faces, 1].==0) .| (N_all[b_faces, 2].==0)
    @assert all(isboundary)
    bc_cells = N_all[b_faces,1] + N_all[b_faces,2]
    b_T_hf   = T_all[b_faces] 

    domain = exported_model_to_domain(ex_model, bc=bc_cells, b_T_hf=b_T_hf)

    timesteps = diff(1:10) * 10
    
    G = ex_model["G"]
    sys = SimpleElyte()
    model = SimulationModel(domain, sys, context = DefaultContext())
    parameters = setup_parameters(model)
    parameters[:t] = ex_model["sp"]["t"][1]
    parameters[:z] = ex_model["sp"]["z"][1]

    S = model.secondary_variables
    S[:BoundaryPhi] = BoundaryPotential{Phi}()
    S[:BoundaryC] = BoundaryPotential{C}()

    init = Dict(
        :Phi            => 1.,
        :C              => 1.,
        :T              => 298.,
        :BoundaryPhi    => b_phi,
        :BoundaryC      => b_c,
        )

    state0 = setup_state(model, init)
  
    sim = Simulator(model, state0=state0, parameters=parameters)
    cfg = simulator_config(sim)
    cfg[:linear_solver] = nothing
    states = simulate(sim, timesteps, config = cfg)
    return states, G, model
end

states, G, model = test_simple_elyte_1d();

##
using Plots
state0 = states[1]

x = G["cells"]["centroids"]
xf = G["faces"]["centroids"][end]
xfi= G["faces"]["centroids"][2:end-1]

plot1 = Plots.plot(x, state0[:Phi]; title = "Phi")
plot2 = Plots.plot([], [], title = "Flux_phi")

p = plot(plot1, plot2, layout = (1, 2), legend = false)

for (n,state) in enumerate(states)
    Plots.plot!(plot1, x, states[n].Phi)
    Plots.plot!(plot2, xfi, states[n].TPkGrad_Phi[1:2:end-1])
    display(plot!(plot1, plot2, layout = (1, 2), legend = false))
end

##

plot1 = Plots.plot(x, state0[:C]; title = "C")
plot2 = Plots.plot([], [], title = "Flux_C")

p = plot(plot1, plot2, layout = (1, 2), legend = false)

for (n,state) in enumerate(states)
    Plots.plot!(plot1, x, states[n].C)
    Plots.plot!(plot2, xfi, states[n].TPkGrad_C[1:2:end-1])
    display(plot!(plot1, plot2, layout = (1, 2), legend = false))
end

##

x = G["cells"]["centroids"]


plot1 = Plots.plot(x, state0.Phi;title="Phi")
plot2 = Plots.plot(x, state0.C;title="C")

p = plot(plot1, plot2, layout = (1, 2), legend = false)
for (n, state) in enumerate(states)
    Plots.plot!(plot1, x, states[n].Phi)
    Plots.plot!(plot2, x, states[n].C)
    display(plot!(plot1, plot2, layout = (1, 2), legend = false))
end
