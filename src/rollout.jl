# RolloutSimulator
# gotten from @zsunberg

"""
    RolloutSimulator(rng, max_steps)
    RolloutSimulator(; <keyword arguments>)
A fast simulator that just returns the reward
The simulation will be terminated when either
1) a terminal state is reached (as determined by `isterminal()` or
2) the diwscount factor is as small as `eps` or
3) max_steps have been executed
# Keyword arguments:
- rng: A random number generator to use.
- eps: A small number; if γᵗ where γ is the discount factor and t is the time step becomes smaller than this, the simulation will be terminated.
- max_steps: The maximum number of steps to simulate.
# Usage (optional arguments in brackets):
    ro = RolloutSimulator()
    history = simulate(ro, pomdp, policy, [updater [, init_belief [, init_state]]])
See also: [`HistoryRecorder`](@ref), [`run_parallel`](@ref)
"""

struct RolloutSimulator{RNG<:AbstractRNG} <: Simulator
    rng::RNG
    # optional: if these are null, they will be ignored
    max_steps::Union{Nothing,Int}
    eps::Union{Nothing,Float64}
end

RolloutSimulator(rng::AbstractRNG, d::Int=typemax(Int)) = RolloutSimulator(rng, d, nothing)
function RolloutSimulator(;rng=Random.GLOBAL_RNG,
                           eps=nothing,
                           max_steps=nothing)
    return RolloutSimulator{typeof(rng)}(rng, max_steps, eps)
end

function simulate(sim::RolloutSimulator, pomdp::ConstrainedPOMDPWrapper, policy::Policy, bu::Updater=updater(policy))
    dist = initialstate(pomdp)
    return simulate(sim, pomdp, policy, bu, dist)
end

function simulate(sim::RolloutSimulator, pomdp::ConstrainedPOMDPWrapper, policy::Policy, updater::Updater, initial_belief) where {S}
    s = rand(sim.rng, initial_belief)::S
    return simulate(sim, pomdp, policy, updater, initial_belief, s)
end

function simulate(sim::RolloutSimulator, pomdp::ConstrainedPOMDPWrapper, policy::Policy, updater::Updater, initial_belief, s)

    if sim.eps == nothing
        eps = 0.0
    else
        eps = sim.eps
    end
    if sim.max_steps == nothing
        max_steps = typemax(Int)
    else
        max_steps = sim.max_steps
    end
    disc = 1.0
    r_total = 0.0
    c_total = zeros(constraint_size(pomdp))
    b = initialize_belief(updater, initial_belief)
    step = 1
    while disc > eps && !isterminal(pomdp, s) && step <= max_steps
        a = action(policy, b)
        sp, o, r, c = gen(pomdp, s, a, sim.rng)
        r_total += disc*r
        c_total += disc*c
        s = sp
        bp = update(updater, b, a, o)
        b = bp
        disc *= discount(pomdp)
        step += 1
    end

    return [r_total,c_total]
end
