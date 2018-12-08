# constants and functions used by multiple types of analyses


# constants

const JSON_DIGITS = 6 # number of decimal points for floats in JSON output

const JULIA_ENV = ENV["JULIA_ENV"]




# functions
# moved to MySQLforQpcrAnalysis.jl: ensure_ci, get_mysql_data_well


# find by sliding window the indices in a vector where the value at the index equals the summary value of the window centering at the index (window width = number of data points in the whole window). can be used to find peak summits and nadirs
function find_mid_sumr_bysw(vals::AbstractVector, half_width::Integer, sumr_func::Function=maximum)
    padding = fill(-sumr_func(-vals), half_width)
    vals_padded = [padding; vals; padding]
    find(1:length(vals)) do i
        vals_iw = vals_padded[i : i + half_width * 2] # iw = in window
        return sumr_func(vals_iw) == vals_iw[half_width + 1]
    end # do i
end


# finite differencing
function finite_diff(
    X::AbstractVector, Y::AbstractVector; # X and Y must be of same length
    nu::Integer=1, # order of derivative
    method::String="central"
    )

    dlen = length(X)
    if dlen != length(Y)
        error("X and Y must be of same length.")
    end

    if dlen == 1
        return zeros(1)
    end

    if nu == 1
        if method == "central"
            range1 = 3:dlen+2
            range2 = 1:dlen
        elseif method == "forward"
            range1 = 3:dlen+2
            range2 = 2:dlen+1
        elseif method == "backward"
            range1 = 2:dlen+1
            range2 = 1:dlen
        end

        X_p2, Y_p2 = map((X, Y)) do ori
            vcat(
                ori[2] * 2 - ori[1],
                ori,
                ori[dlen-1] * 2 - ori[dlen]
            )
        end

        return (Y_p2[range1] .- Y_p2[range2]) ./ (X_p2[range1] .- X_p2[range2])

    else
        return finite_diff(
            X,
            finite_diff(X, Y; nu=nu-1, method=method),
            nu=1;
            method=method)
    end # if nu == 1

end

# construct DataFrame from dictionary key and value vectors
# `dict_keys` need to be a vector of strings to construct DataFrame column indices correctly
function dictvec2df(dict_keys::AbstractVector, dict_values::AbstractVector) 
    df = DataFrame()
    for dict_key in dict_keys
        df[parse(dict_key)] = map(dict_ele -> dict_ele[dict_key], dict_values)
    end
    return df
end


# duplicated in MySQLforQpcrAnalysis.jl
function get_ordered_keys(dict::Dict)
    sort(collect(keys(dict)))
end
function get_ordered_keys(ordered_dict::OrderedDict)
    collect(keys(ordered_dict))
end


# functions to get indices in span.
    # x_mp_i = index of middle point in selected data points from X
    # sel_idc = selected indices

function giis_even(dlen::Integer, i::Integer, span_dp::Integer)
    start_idx = i > span_dp ? i - span_dp : 1
    end_idx = i < dlen - span_dp ? i + span_dp : dlen
    return start_idx:end_idx
end

function giis_uneven(
    X::AbstractVector,
    i::Integer, span_x::Real)
    return find(X) do x_dp
        X[i] - span_x <= x_dp <= X[i] + span_x # dp = data point
    end # do x_dp
end


# mutate duplicated elements in a numeric vector so that all the elements become unique
function mutate_dups(vec_2mut::AbstractVector, frac2add::Real=0.01)

    vec_len = length(vec_2mut)
    vec_uniq = sort(unique(vec_2mut))
    vec_uniq_len = length(vec_uniq)

    if vec_len == vec_uniq_len
        return vec_2mut
    else
        order_to = sortperm(vec_2mut)
        order_back = sortperm(order_to)
        vec_sorted = (vec_2mut + .0)[order_to]
        vec_sorted_prev = vcat(vec_sorted[1]-1, vec_sorted[1:vec_len-1])
        dups = (1:vec_len)[map(1:vec_len) do i
            vec_sorted[i] == vec_sorted_prev[i]
        end]

        add1 = frac2add * median(map(2:vec_uniq_len) do i
            vec_uniq[i] - vec_uniq[i-1]
        end)

        for dup_i in 1:length(dups)
            dup_i_moveup = dup_i
            rank = 1
            while dup_i_moveup > 1 && dups[dup_i_moveup] - dups[dup_i_moveup-1] == 1
                dup_i_moveup -= 1
                rank += 1
            end
            vec_sorted[dups[dup_i]] += add1 * rank
        end

        return vec_sorted[order_back]
    end

end


# parse AbstractFloat on BBB
function parse_af{T<:AbstractFloat}(::Type{T}, strval::String)
    str_parts = split(strval, '.')
    float_parts = map(str_part -> parse(Int32, str_part), str_parts)
    return float_parts[1] + float_parts[2] / 10^length(str_parts[2])
end


# print with verbose control
function print_v(print_func::Function, verbose::Bool, args...; kwargs...)
    if verbose
        print_func(args...; kwargs...)
    end
    return nothing
end


# repeat n times: take the output of an function and use it as the input for the same function
function redo(func::Function, input, times::Integer, extra_args...; kwargs...)
    output = input
    while times > 0
        output = func(output, extra_args...; kwargs...)
        times -= 1
    end
    return output
end


# reshape a layered vector into a multi-dimension array, where outer layer is converted to higher dimension and each element has `num_layers_left` layers left (e.g. each element is atomic / not an array when `num_layers_lift == 0`, a vector of atomic elements when `num_layers_lift == 1`, vector of vector of atomic elements when `num_layers_lift == 2`).
function reshape_lv(layered_vector::AbstractVector, num_layers_left::Integer=0)
    md_array = copy(layered_vector) # safe in case `eltype(layered_vector) <: AbstractArray`
    while redo(eltype, md_array, num_layers_left + 1) <: AbstractArray
        md_array = reshape(
            cat(2, md_array...),
            length(md_array[1]),
            size(md_array)...
        )
    end
    return md_array
end




#
