using DrWatson
@quickactivate "NIPS_2020_NPUX"

using DataFrames
using Statistics
using Flux
using ValueHistories
using NeuralArithmetic
include(joinpath(@__DIR__, "configs.jl"))

function aggregateruns(df::DataFrame)
    gdf = groupby(df, :hash)
    combine(gdf) do df
        (μmse = mean(df.mse),
         σmse = std(df.mse),
         μreg = mean(df.reg),
         σreg = std(df.reg),
         μtrn = mean(df.trn),
         σtrn = std(df.trn),
         μval = mean(df.val),
         σval = std(df.val),
         fstinit = first(df.fstinit),
         sndinit = first(df.sndinit),
         model = first(df.model),
         task = first(df.task))
    end
end

function expand_config!(df::DataFrame)
    if "config" in names(df)
        for k in fieldnames(typeof(df.config[1]))
            df[!,k] = getfield.(df.config, k)
        end
    elseif "c" in names(df)
        for k in fieldnames(typeof(df.c[1]))
            df[!,k] = getfield.(df.c, k)
        end
    else
        error("neither `config` nor `c` in dataframe")
    end
end

function find_best(hash::UInt, df::DataFrame, key::String)
    fdf = filter(row->row[:hash]==hash, df)
    sort!(fdf, key)
    fdf[1,:path]
end


Base.last(h::MVHistory, k::Symbol) = get(h,k)[2][end]

function collect_folder!(folder::String)
     _df = collect_results!(datadir(folder), white_list=[],
                          special_list=[:trn => data -> last(data[:history], :loss)[1],
                                        :mse => data -> last(data[:history], :loss)[2],
                                        :reg => data -> last(data[:history], :loss)[3],
                                        :val => data -> last(data[:history], :loss)[4],
                                        :config => data -> data[:c],
                                        :hash => data -> hash(delete!(struct2dict(data[:c]),:run)),
                                        :task => data -> split(basename(folder),"_")[1],
                                       ],
                         )
    expand_config!(_df)
    return _df
end

collect_all_results!(folders::Vector{String}) = vcat(map(collect_folder!, folders)...)

"""
Creates table like this:
| task | npu | npux | ... |
"""
function best_models_for_tasks(df::DataFrame, key::String)
    best = combine(groupby(df,"model")) do modeldf
        combine(groupby(modeldf, "task")) do taskdf
            tdf = sort!(DataFrame(taskdf[1,:]), key)
            tdf[1,:]
        end
    end

    best = select(best, "model", "task", key)
    tasks = unique(best, "task").task
    models = unique(best, "model").model

    result = DataFrame(Union{Float64,Missing}, length(tasks), length(models)+1)
    #DataFrame([Vector{t}(undef, nrows) for i = 1:ncols])
    rename!(result, vcat(["task"], models))
    result[!,1] = tasks

    #result.models = models
    for m in models
        mdf = filter(:model=>model->model==m, best)
        for (i,t) in zip(1:length(tasks), tasks)
            mtdf = filter(:task=>task->task==t, mdf)
            if size(mtdf) == (1,3)
                v = mtdf[1,key]
                result[i,m] = v
            elseif size(mtdf) == (0,3)
                result[i,m] = missing
            else
                error("Expected single row no row.")
            end
        end
    end
    return result
end

function plot_result_folder(df::DataFrame, cols::Vector{String}, measure::String)
    ps = []
    gdf = groupby(df, "model")

    modelplot = plot(title="models", yscale=:log10, legend=false)

    for (name,_df) in zip(keys(gdf), gdf)
        name = name[1]
        m = _df[!,measure] 
        plot!(modelplot, [name for _ in 1:length(m)], m)
        plot!(modelplot, [name], [minimum(m)], marker="o")
        for col in cols
            v = _df[!,col]
            xscale = col=="βend" ? :log10 : :identity
            p = scatter(v,m, xlabel=col, ylabel=measure, title=name,
                        yscale=:log10, xscale=xscale)
            push!(ps, p)
        end

    end
    #plot(ps...,modelplot)
    plot(ps...,modelplot,layout=(:,3))
end

key = "val"
folders = ["addition_npu_l1_search"
          ,"mult_npu_l1_search"
          ,"sqrt_npu_l1_search"
          ,"div_npu_l1_search"]
folders = map(datadir, folders)

# _df = collect_folder!(folders[1])
# pyplot()
# display(plot_result_folder(_df,["βend", "fstinit", "sndinit"], key))
# error()

df = collect_all_results!(folders)
adf = aggregateruns(df)

models = ["gatednpux","nmu","nalu"]
bestdf = best_models_for_tasks(df, key)
bestdf = best_models_for_tasks(adf, "μ$key")
#sort!(adf,"μ$key")

# folder = folders[3]
# df = collect_results!(datadir(folder), white_list=[],
#                       special_list=[:trn => data -> last(data[:history], :loss)[1],
#                                     :mse => data -> last(data[:history], :loss)[2],
#                                     :reg => data -> last(data[:history], :loss)[3],
#                                     :val => data -> last(data[:history], :loss)[4],
#                                     :config => data -> data[:c],
#                                     :hash => data -> hash(delete!(struct2dict(data[:c]),:run)),
#                                     :task => data -> split(folder,"_")[1],
#                                    ],
#                      )
# expand_config!(df)
# key = "val"
# display(df)
# 
# adf = aggregateruns(df)
# sort!(adf,"μ$key")
# display(adf)
# 
# bestrun = find_best(adf[1,:hash], df, key)
# #bestrun = sort!(df,key)[1,:path]
# res = load(bestrun)
# @unpack model, history = res
# 
# using UnicodePlots
# UnicodePlots.heatmap(model[1].W[end:-1:1,:], height=100, width=100)

