export fit, fit!, Params,
       objective, error_metric

### PARAMETERS TYPE
abstract AbstractParams
Params(args...; kwargs...) = ProxGradParams(args...; kwargs...)

# default in-place fitting uses proximal gradient method
function fit!(glrm::GLRM; kwargs...)
    println(kwargs)
    if :params in keys(kwargs)
        return fit!(glrm, kwargs[:params]; kwargs...)
    else
        return fit!(glrm, ProxGradParams(); kwargs...)
    end
end

# fit without modifying the glrm object
function fit(glrm::GLRM, args...; kwargs...)
    X0 = Array(Float64, size(glrm.X))
    Y0 = Array(Float64, size(glrm.Y))
    copy!(X0, glrm.X); copy!(Y0, glrm.Y)
    X,Y,ch = fit!(glrm, args...; kwargs...)
    copy!(glrm.X, X0); copy!(glrm.Y, Y0)
    return X',Y,ch
end

### OBJECTIVE FUNCTION EVALUATION
function objective(glrm::GLRM, X::Array{Float64,2}, Y::Array{Float64,2}, 
                   XY::Array{Float64,2}; include_regularization=true)
    m,n = size(glrm.A)
    err = 0
    for j=1:n
        for i in glrm.observed_examples[j]
            err += evaluate(glrm.losses[j], XY[i,j], glrm.A[i,j])
        end
    end
    # add regularization penalty
    if include_regularization
        for i=1:m
            err += evaluate(glrm.rx, view(X,:,i))
        end
        for j=1:n
            err += evaluate(glrm.ry[j], view(Y,:,j))
        end
    end
    return err
end
# The user can also pass in X and Y and `objective` will compute XY for them
function objective(glrm::GLRM, X::Array{Float64,2}, Y::Array{Float64,2}; kwargs...)
    XY = Array(Float64, size(glrm.A)) 
    gemm!('T','N',1.0,X,Y,0.0,XY) 
    objective(glrm, X, Y, XY; kwargs...)
end
# Or just the GLRM and `objective` will use glrm.X and .Y
objective(glrm::GLRM; kwargs...) = objective(glrm, glrm.X, glrm.Y; kwargs...)

## ERROR METRIC EVALUATION (BASED ON DOMAINS OF THE DATA)
function error_metric(glrm::GLRM, XY::Array{Float64,2}, domains::Array{Domain,1})
    m,n = size(glrm.A)
    err = 0
    for j=1:n
        for i in glrm.observed_examples[j]
            err += error_metric(domains[j], glrm.losses[j], XY[i,j], glrm.A[i,j])
        end
    end
    return err
end
# The user can also pass in X and Y and `error_metric` will compute XY for them
function error_metric(glrm::GLRM, X::Array{Float64,2}, Y::Array{Float64,2}, domains::Array{Domain,1})
    XY = Array(Float64, size(glrm.A)) 
    gemm!('T','N',1.0,X,Y,0.0,XY) 
    error_metric(glrm, XY, domains)
end
# Or just the GLRM and `error_metric` will use glrm.X and .Y
error_metric(glrm::GLRM, domains::Array{Domain,1}) = error_metric(glrm, glrm.X, glrm.Y, domains)