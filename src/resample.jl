"""
```
resample(weights::AbstractArray; n_parts::Int64 = length(weights),
    method::Symbol = :systematic, parallel::Bool = false)
```

Reindexing and reweighting samples from a degenerate distribution

### Input Arguments
- `weights`: wtsim[:,i]
        the weights of a degenerate distribution.

### Keyword Arguments
- `n_parts`: length(weights)
        the desired length of output vector
- `method`: :systematic, :multinomial, or :polyalgo
        the method for resampling
- `parallel`: if true, mulitnomial sampling will be done in parallel.

### Output:
- `indx`: the newly assigned indices of parameter draws.
"""
function resample(weights::Vector{Float64}; n_parts::Int64 = length(weights),
                  method::Symbol = :systematic, parallel::Bool = false)

    if method == :multinomial

        # Stores cumulative weights until given index
        cumulative_weights = cumsum(weights ./ sum(weights))
        offset = rand(n_parts)

        if parallel
            indx = @sync @distributed (vcat) for i in 1:n_parts
                findfirst(x -> offset[i] < x, cumulative_weights)
            end
        else
            indx = Vector{Int64}(undef, n_parts)

            for i in 1:n_parts
                indx[i] = findfirst(x -> offset[i] < x, cumulative_weights)
            end
        end

        return indx
    elseif method == :systematic
        # Stores cumulative weights until given index
        cumulative_weights = cumsum(weights ./ sum(weights))
        offset = rand()

        # Function solves where an individual "spoke" lands
        function subsys(i::Int, offset::Float64, n_parts::Int64, start_ind::Int64,
                        cumulative_weights::Vector{Float64})
            threshold = (i - 1 + offset) / n_parts
            range = start_ind:n_parts
            for j in range
                if cumulative_weights[j] > threshold
                    return j
                end
            end
            return 0
        end

        indx = Vector{Int64}(undef, n_parts)
        for i in 1:n_parts
            if i == 1
                indx[i] = subsys(i, offset, n_parts, 1, cumulative_weights)
            else
                indx[i] = subsys(i, offset, n_parts, indx[i-1], cumulative_weights)
            end
        end
        return indx

    elseif method == :polyalgo
        weights = Weights(weights ./ sum(weights))
        return sample(1:length(weights), weights, n_parts, replace = true)
    else
        throw("Invalid resampler in SMC. Options are :systematic, :multinomial, or :polyalgo")
    end
end
