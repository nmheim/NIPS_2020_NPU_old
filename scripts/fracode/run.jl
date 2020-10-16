using DrWatson
@quickactivate

include(joinpath(@__DIR__, "npu-sir.jl"))
include(joinpath(@__DIR__, "realnpu-sir.jl"))
include(joinpath(@__DIR__, "dense-sir.jl"))

@progress for nr in 1:5
    hdims = [6,9,12,15,20]
    βpss  = [0., 1e-2, 1e-1, 1.]
    @progress for (hdim,βps) in Iterators.product(hdims, βpss)

        produce_or_load(datadir("fracsir"),
                        Dict{Symbol,Any}(
                             :hdim=>hdim,
                             :βim=>0,
                             :βps=>βps,
                             :lr=>0.005,
                             :niters=>3000,
                             :αinit=>0.2,
                             :run=>nr),
                        run_npu,
                        prefix="npu",
                        digits=10,
                        force=false)

        produce_or_load(datadir("fracsir"),
                        Dict{Symbol,Any}(
                             :hdim=>hdim,
                             :βim=>0,
                             :βps=>βps,
                             :lr=>0.005,
                             :niters=>3000,
                             :αinit=>0.2,
                             :run=>nr),
                        run_realnpu,
                        prefix="realnpu",
                        digits=10,
                        force=false)

        produce_or_load(datadir("fracsir"),
                        Dict{Symbol,Any}(
                             :hdim=>hdim,
                             :βps=>βps,
                             :lr=>0.005,
                             :niters=>3000,
                             :αinit=>1,
                             :run=>nr),
                        run_dense,
                        prefix="dense",
                        digits=10,
                        force=false)
    end
end
