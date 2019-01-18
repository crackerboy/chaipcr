## types_for_sfc_models.jl

import DataStructures.OrderedDict
using JuMP


## sfc: same formula for each cycle
struct SfcFitted <: AbstractAmpFitted
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float64}
    status      ::Symbol
    obj_val     ::AbstractFloat
    jmp_model   ::JuMP.Model
    init_coefs  ::OrderedDict{String,Float64}
end
const SfcFitted_EMPTY = SfcFitted(
    Vector{String}(), # coef_strs
    zeros(0), # coefs
    :not_fitted, # status
    0., # obj_val
    JuMP.Model(),
    OrderedDict{String,Float64}() # init_coefs
)

mutable struct SFCModelDef # non-linear model, one feature (`x`)
    ## included in SFC_MODEL_BASE
    name            ::Symbol
    linear          ::Bool
    _x_strs         ::AbstractVector
    X_strs          ::AbstractVector
    coef_strs       ::AbstractVector
    coef_cnstrnts   ::AbstractVector # assume all linear
    func_init_coefs ::Function
    pred_strs       ::OrderedDict
    ## added by `add*!`` functions
    func_pred_strs  ::OrderedDict
    funcs_pred      ::OrderedDict
    func_fit_str    ::String
    func_fit        ::Function
end

const MD_func_keys = [:f, :inv, :bl, :dr1, :dr2] # when `num_fts > 1`, "d*" are partial derivatives in vector of length `num_fts`

# function empty_func() end
function empty_func(args...; kwargs...) end
# function empty_func(arg1::Any=0, args...; kwargs...) end

## `EMPTY_fp` for `func_pred_strs` and `funcs_pred`
const EMPTY_fp = map(("", empty_func)) do empty_val
    ## OrderedDict(map(MD_func_keys) do func_key # v0.4, `supertype` not defined, `typeof(some_function) == Function`
    OrderedDict{Symbol,supertype(typeof(empty_val))}(map(MD_func_keys) do func_key # v0.5, `super` becomes `supertype`, `typeof(some_function) == #some_function AND supertype(typeof(some_function)) == Function`
        func_key => empty_val
    end) # do func_key
end # do empty_val

const MD_EMPTY_vals = (
    EMPTY_fp..., # :func_pred_strs, :funcs_pred
    "", # func_fit_str
    empty_func # func_fit
)

const SFC_MODEL_BASES = [ # vector of tuples

## generic

    (
        :lin_1ft,
        true,
        ["_x"],
        ["X"],
        ["c0", "c1"],
        [],
        function lin_1ft_func_init_coefs(args...; kwargs...)
            OrderedDict("c0"=>0, "c1"=>0)
        end,
        OrderedDict(
            :f   => "c0 + c1 * _x",
            :inv => "(_x - c0) / c1",
            :bl  => "0",
            :dr1 => "c1",
            :dr2 => "0"
        )
    ),

    (
        :lin_2ft,
        true,
        ["_x1", "_x2"],
        ["X1", "X2"],
        ["c0", "c1", "c2"],
        [],
        function lin_2ft_func_init_coefs(args...; kwargs...)
            OrderedDict("c0"=>0, "c1"=>0, "c2"=>0)
        end,
        OrderedDict(
            :f   => "c0 + c1 * _x1 + c2 * _x2",
            :inv => "0", # not applicable
            :bl  => "0",
            :dr1 => "[c1, c2]",
            :dr2 => "[0, 0]"
        )
    ),


# amplification curve

    (
        :b4,
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_"],
        [],
        function b4_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.001
            )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(X[idc_4be], Y_logit)
            b_ = lin1_coefs[2]
            e_ = -lin1_coefs[1] / b_
            return OrderedDict("b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_)
        end,
        OrderedDict(
            :f   => "c_ + (d_ - c_) / (1 + exp(b_ * (_x - e_)))",
            :inv => "log((-d_ + _x) / (c_ - _x)) / b_ + e_",
            :bl  => "c_",
            :dr1 =>
                "(b_ * (c_ - d_) * exp(b_ * (e_ + _x)))/(exp(b_ * e_) + exp(b_ * _x))^2",
            :dr2 =>
                "(b_^2 * (c_ - d_) * exp(b_ * (e_ + _x)) * (exp(b_ * e_) - exp(b_ * _x)))/(exp(b_ * e_) + exp(b_ * _x))^3"
        )
    ),

    (
        :l4, # name
        false, # linear
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_"], # coef_strs
        ["e_ >= 1e-100"], # removing bound did not improve Cq accuracy
        function l4_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            return OrderedDict("b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_)
        end,
        OrderedDict( # pred_strs
            :f   => "c_ + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "((e_^b_ * (-d_ + _x))/(c_ - _x))^(1/b_)",
            :bl  => "c_",
            :dr1 => "(b_ * (c_ - d_) * e_^b_ * _x^(-1 + b_)) / (e_^b_ + _x^b_)^2",
            :dr2 =>
                "(b_ * (c_ - d_) * e_^b_ * _x^(-2 + b_) * ((-1 + b_) * e_^b_ - (1 + b_) * _x^b_))/(e_^b_ + _x^b_)^3"
        )
    ),

    (
        :l4_hbl, # hyperbolic baseline: increase before log-phase then minimal at plateau (most simple version is -1/x). baseline model `c + bl_k / (e_ - x)` model caused "Ipopt finished with status Restoration_Failed"
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "bl_k", "bl_o"],
        ["e_ >= 1e-100"],
        function l4_hbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            bl_k = 0
            bl_o = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "bl_k"=>bl_k, "bl_o"=>bl_o
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + bl_k / (_x + bl_o) + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + bl_k / (_x + bl_o)",
            :dr1 =>
                "-bl_k / (_x + bl_o)^2 + (b_ * (c_ - d_) * e_^b_ * _x^(-1 + b_)) / (e_^b_ + _x^b_)^2",
            :dr2 =>
                "bl_k / (_x + bl_o)^3 + (b_ * (c_ - d_) * e_^b_ * _x^(-2 + b_) * ((-1 + b_) * e_^b_ - (1 + b_) * _x^b_))/(e_^b_ + _x^b_)^3"
        )
    ),

    (
        :l4_lbl, # linear baseline
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "k1"],
        ["e_ >= 1e-100"],
        function l4_lbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            k1 = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "k1"=>k1
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + k1 * _x + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + k1 * _x",
            :dr1 =>
                "k1 + (b_ * (c_ - d_) * e_^b_ * _x^(-1 + b_)) / (e_^b_ + _x^b_)^2",
            :dr2 =>
                "(b_ * (c_ - d_) * e_^b_ * _x^(-2 + b_) * ((-1 + b_) * e_^b_ - (1 + b_) * _x^b_))/(e_^b_ + _x^b_)^3"
        )
    ),

    (
        :l4_qbl, # quadratic baseline
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "k1", "k2"],
        ["e_ >= 1e-100"],
        function l4_qbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            k1 = 0
            k2 = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "k1"=>k1, "k2"=>k2
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + k1 * _x + k2 * _x^2 + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + k1 * _x + k2 * _x^2",
            :dr1 =>
                "k1 + 2 * k2 * _x + (b_ * (c_ - d_) * e_^b_ * _x^(-1 + b_)) / (e_^b_ + _x^b_)^2",
            :dr2 =>
                "2 * k2 + (b_ * (c_ - d_) * e_^b_ * _x^(-2 + b_) * ((-1 + b_) * e_^b_ - (1 + b_) * _x^b_))/(e_^b_ + _x^b_)^3"
        )
    ),

    (
        :l4_enl, # name
        false, # linear
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_"], # coef_strs
        [], # coef_cnstrnts
        function l4_enl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = -lin1_coefs[1] / b_
            return OrderedDict("b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_)
        end,
        OrderedDict( # pred_strs
            :f   => "c_ + (d_ - c_) / (1 + exp(b_ * (log(_x) - e_)))",
            :inv => "((exp(e_ * b_) * (-d_ + _x))/(c_ - _x))^(1/b_)",
            :bl  => "c_",
            :dr1 => "(b_ * (c_ - d_) * exp(e_ * b_) * _x^(-1 + b_)) / (exp(e_ * b_) + _x^b_)^2",
            :dr2 =>
                "(b_ * (c_ - d_) * exp(e_ * b_) * _x^(-2 + b_) * ((-1 + b_) * exp(e_ * b_) - (1 + b_) * _x^b_))/(exp(e_ * b_) + _x^b_)^3"
        )
    ),

    (
        :l4_enl_hbl, # hyperbolic baseline: increase before log-phase then minimal at plateau (most simple version is -1/x). baseline model `c + bl_k / (e_ - x)` model caused "Ipopt finished with status Restoration_Failed"
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "bl_k", "bl_o"],
        [],
        function l4_enl_hbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            bl_k = 0
            bl_o = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "bl_k"=>bl_k, "bl_o"=>bl_o
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + bl_k / (_x + bl_o) + (d_ - c_) / (1 + exp(b_ * (log(_x) - e_)))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + bl_k / (_x + bl_o)",
            :dr1 =>
                "-bl_k / (_x + bl_o)^2 + (b_ * (c_ - d_) * exp(e_ * b_) * _x^(-1 + b_)) / (exp(e_ * b_) + _x^b_)^2",
            :dr2 =>
                "bl_k / (_x + bl_o)^3 + (b_ * (c_ - d_) * exp(e_ * b_) * _x^(-2 + b_) * ((-1 + b_) * exp(e_ * b_) - (1 + b_) * _x^b_))/(exp(e_ * b_) + _x^b_)^3"
        )
    ),

    (
        :l4_enl_lbl, # linear baseline
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "k1"],
        [],
        function l4_enl_lbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            k1 = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "k1"=>k1
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + k1 * _x + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + k1 * _x",
            :dr1 =>
                "k1 + (b_ * (c_ - d_) * exp(e_ * b_) * _x^(-1 + b_)) / (exp(e_ * b_) + _x^b_)^2",
            :dr2 =>
                "(b_ * (c_ - d_) * exp(e_ * b_) * _x^(-2 + b_) * ((-1 + b_) * exp(e_ * b_) - (1 + b_) * _x^b_))/(exp(e_ * b_) + _x^b_)^3"
        )
    ),

    (
        :l4_enl_qbl, # quadratic baseline
        false,
        ["_x"],
        ["X"],
        ["b_", "c_", "d_", "e_", "k1", "k2"],
        [],
        function l4_enl_qbl_func_init_coefs(
            X::AbstractVector,
            Y::AbstractVector,
            epsilon::Real=0.01
        )
            Y_min, Y_min_idx = findmin(Y)
            c_ = Y_min - epsilon
            d_ = maximum(Y) + epsilon
            idc_4be = Y_min_idx:length(Y)
            Y_4be = Y[idc_4be]
            Y_logit = log.((d_ - Y_4be) ./ (Y_4be - c_))
            lin1_coefs = linreg(log.(X[idc_4be]), Y_logit)
            b_ = lin1_coefs[2]
            e_ = exp(-lin1_coefs[1] / b_)
            k1 = 0
            k2 = 0
            return OrderedDict(
                "b_"=>b_, "c_"=>c_, "d_"=>d_, "e_"=>e_,
                "k1"=>k1, "k2"=>k2
            )
        end,
        OrderedDict( # pred_strs
            :f   =>
                "c_ + k1 * _x + k2 * _x^2 + (d_ - c_) / (1 + exp(b_ * (log(_x) - log(e_))))",
            :inv => "0", # not calculated yet
            :bl  => "c_ + k1 * _x + k2 * _x^2",
            :dr1 =>
                "k1 + 2 * k2 * _x + (b_ * (c_ - d_) * exp(e_ * b_) * _x^(-1 + b_)) / (exp(e_ * b_) + _x^b_)^2",
            :dr2 =>
                "2 * k2 + (b_ * (c_ - d_) * exp(e_ * b_) * _x^(-2 + b_) * ((-1 + b_) * exp(e_ * b_) - (1 + b_) * _x^b_))/(exp(e_ * b_) + _x^b_)^3"
        )
    )
]

# generate generic md objects
const MDs = OrderedDict(map(SFC_MODEL_BASES) do sfc_model_base
    sfc_model_base[1] => SFCModelDef(
        sfc_model_base...,
        deepcopy(MD_EMPTY_vals)...
    )
end) # do generic_sfc_model_base

# choose model for amplification curve fitting
const AMP_MODEL_NAME = :l4_enl
const AMP_MD = MDs[AMP_MODEL_NAME]
