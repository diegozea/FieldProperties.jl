"""
    Property{name}

A `Property` serves as a common reference point for accessing methods related to `name`,
where `name` is the dot accessed field (as in `x.<name>`).

See [`@defprop`](@ref), [`@assignprops`](@ref)
"""
struct Property{name} end

Property(name) = Property{name}()

Base.show(io::IO, p::Property) = _show_property(io, p)
Base.show(io::IO, ::MIME"text/plain", p::Property) = _show_property(io, p)

_show_property(io, ::Property{name}) where {name} = print(io, "Property(:$name)")

"""
    NotProperty

Indicator for the absence of a property.
"""
const NotProperty = Property{nothing}()
_show_property(io, ::Property{nothing}) = print(io, "NotProperty")

"""
    getter(x, p)
"""
@inline getter(x, p::Property) = getter(x, p, prop2sym(x, p))
@inline getter(x, s::Symbol) = getter(x, sym2prop(x, s), s)

# s should be field of x 
getter(x, p::Property, s::Symbol) = getfield(x, s)

# coudn't map `s` to property given `x` so NotProperty unless:
# 1. x::AbstractDict{Symbol} has key `s`
# 2. x has nested field with `s`
function getter(x, p::Property{nothing}, s::Symbol)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = getter(getfield(x, f), s)
            out !== NotProperty && return out
        end
    else
        out = NotProperty
    end
    return out
end
function getter(x::AbstractDict{Symbol}, ::Property{nothing}, s::Symbol)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = getter(getfield(x, f), s)
            out !== NotProperty && return out
        end
    else
        out = NotProperty
    end
    if out === NotProperty
        out = get(x, s, NotProperty)
    end
    return out
end

# coudn't map `p` to field given `x` so NotProperty unless:
# 1. x::AbstractDict{Symbol} has key `s`
# 2. x has nested field with `s`
function getter(x, p::Property, s::Nothing)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = getter(getfield(x, f), p)
            out !== NotProperty && return out
        end
    else
        out = NotProperty
    end
    return out
end

function getter(x::AbstractDict{Symbol}, p::Property, ::Nothing)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = getter(getfield(x, f), p)
            out !== NotProperty && return out
        end
    else
        out = NotProperty
    end
    if out === NotProperty
        out = get(x, propname(p), NotProperty)
    end
    return out
end

"""
    setter!(x, p, val)
"""
@inline setter!(x, p::Property, val) = setter!(x, p, prop2sym(x, p), val)
@inline setter!(x, s::Symbol, val) = setter!(x, sym2prop(x, s), s, val)

# s should be field of x 
setter!(x, p::Property, s::Symbol, val) = setfield!(x, s, val)

# TODO what if we want to dict property at top lavel an dnot just first nested field
# coudn't map `s` to property given `x` so NotProperty unless:
# 1. x::AbstractDict{Symbol} has key `s`
# 2. x has nested field with `s`
function setter!(x, p::Property{nothing}, s::Symbol, val)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = setter!(getfield(x, f), s, val)
            out && break
        end
    else
        out = false
    end
    return out
end
function setter!(x::AbstractDict{Symbol}, ::Property{nothing}, s::Symbol, val)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = setter!(getfield(x, f), s, val)
            out && break
        end
    else
        out = false
    end
    if !out
        setindex!(x, val, s)
        out = true
    end
    return out
end

# coudn't map `p` to field given `x` so NotProperty unless:
# 1. x::AbstractDict{Symbol} has key `s`
# 2. x has nested field with `s`
function setter!(x, p::Property, s::Nothing, val)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = setter!(getfield(x, f), p, val)
            out && break
        end
    else
        out = false
    end
    return out
end

function setter!(x::AbstractDict{Symbol}, p::Property, ::Nothing, val)
    Base.@_inline_meta
    if has_nested_properties(x)
        for f in _nested_fields(x)
            out = setter!(getfield(x, f), p, val)
            out && break
        end
    else
        out = false
    end
    if !out
        setindex!(x, val, propname(p))
        out = true
    end
    return out
end

# Only ensure type stability when going through _getproperty/_setproperty!
_getproperty(x, s::Symbol) = _getproperty(x, sym2prop(x, s), s)
_getproperty(x, p::Property) = _getproperty(x, p, prop2sym(x, p))
_getproperty(x, p, s) = propconvert(x, p, getter(x, p, s))

_setproperty!(x, s::Symbol, val) = _setproperty!(x, sym2prop(x, s), s, val)
_setproperty!(x, p::Property, val) = _setproperty!(x, p, prop2sym(x, p), val)
_setproperty!(x, p, s, val) = (setter!(x, p, s, propconvert(x, p, val)); x)

"""
    property(x) -> Property
"""
property(::T) where {T} = property(T)
property(p::Property) = p
property(::Type{T}) where {T} = NotProperty
property(::Type{T}) where {T<:Property} = T()


"""
    propname(::T) -> Symbol
"""
propname(::P) where {P} = propname(P)
propname(::Type{Property{name}}) where {name} = name
# try to catch setters, getters that belong to a property
propname(::Type{P}) where {P<:Function} = _propname(P, property(P))
_propname(::Type{F}, ::Property{nothing}) where {F<:Function} = Symbol(F.instance)
_propname(::Type{F}, ::Property{name}) where {F<:Function,name} = name

"""
    propdefault(property, context)
"""
propdefault(::P, context::C=nothing) where {P,C} = propdefault(P, C)
propdefault(::P, ::Type{C}) where {P,C} = propdefault(P, C)
propdefault(::Type{P}, context::C=nothing) where {P,C} = propdefault(P, C)
propdefault(::Type{P}, ::Type{C}) where {P<:Property,C} = propdefault(property(P), C)
propdefault(::Type{P}, ::Type{C}) where {P,C} = nothing

"""
    proptype(p[, context]) -> Type

Return the appropriate type for property `p` given `context`.
"""
proptype(::P, context::C=nothing) where {P,C} = proptype(P, C)
proptype(::P, ::Type{C}) where {P,C} = proptype(P, C)
proptype(::Type{P}, context::C=nothing) where {P,C} = proptype(P, C)
proptype(::Type{P}, ::Type{C}) where {P,C} = proptype(property(P), C)
proptype(::Type{P}, ::Type{C}) where {P<:Property,C} = Any

# TODO better docs for propconvert
"""
    propconvert(x, p, v)

Ensures the `val` is the appropriate type for property `p` given `x`. If it isn't
then `ensure_type` attempts to convert to the correct type.
"""
propconvert(x, p::Property, v) = propconvert(x, p, proptype(p, x), v)
propconvert(x, p::Property, ::Type{T}, v::V) where {T,V<:T} = v
propconvert(x, p::Property, ::Type{T}, v::V) where {T,V} = convert(T, v)
function propconvert(x, p::Property, ::Type{T}, ::Property{nothing}) where {T}
    error("type $(typeof(x).name) does not have property $(propname(p))")
end

"""
    propdoc(x)

Returns documentation for property `x`.
"""
propdoc(x) = propdoc(stdout, x)
propdoc(io::IO, x) = propdoc(io, property(x))
function propdoc(io::IO, x::Property)
    buffer = IOBuffer()
    println(buffer, Base.Docs.doc(x))
    Markdown.parse(String(take!(buffer)))
end
#    println(buffer, )
#    Markdown.parse(String(take!(buffer)))
#=
neurohelp(func) = neurohelp(stdout, func)
neurohelp(io::IO, input::Symbol) = neurohelp(io, getproperty(NeuroCore, input))
function neurohelp(io::IO, input)
    buffer = IOBuffer()
    println(buffer, Base.Docs.doc(input))
    Markdown.parse(String(take!(buffer)))
end
=#


"""
    prop2sym(x, property) -> Symbol
"""
prop2sym(::T, p::P) where {T,P} = prop2sym(T, property(P))
prop2sym(::T, ::Type{P}) where {T,P} = prop2sym(T, P)
prop2sym(::Type{T}, ::P) where {T,P} = prop2sym(T, P)
prop2sym(::Type{T}, ::Type{P}) where {T,P} = prop2sym(C, property(P))
prop2sym(::Type{T}, ::Type{P}) where {T,P<:Property} = nothing

"""
    sym2prop(x, sym) -> Property
"""
sym2prop(::T, s::Symbol) where {T} = sym2prop(T, s)
sym2prop(::Type{T}, s::Symbol) where {T} = NotProperty


# TODO document this as one reserved property name
const Properties = Property{:properties}()

"""
    NestedProperty

Indicator for a field containing properties nested within a structure.
"""
const NestedProperty = Property{Properties}()
_show_property(io, ::Property{Properties}) = print(io, "NestedProperty")

#=
    _nested_fields(T) -> Tuple{Vararg{Symbol}}
Returns the fields labeled as `NestedProperty` using `@assignprops`
=#
_nested_fields(::T) where {T} = _nested_fields(T)
_nested_fields(::Type{T}) where {T} = ()

"""
    has_nested_properties(::T) -> Bool

Returns `true` if `T` has fields that contain nested properties.
"""
@inline has_nested_properties(::T) where {T} = has_nested_properties(T)
@inline has_nested_properties(::Type{T}) where {T} = _has_nested_properties(_nested_fields(T))
_has_nested_properties(::Tuple{}) = false
_has_nested_properties(::Tuple{Vararg{Symbol}}) = true