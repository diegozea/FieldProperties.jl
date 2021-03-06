# FieldProperties.jl
[![Build Status](https://travis-ci.com/Tokazama/FieldProperties.jl.svg?branch=master)](https://travis-ci.com/Tokazama/FieldProperties.jl)

## Introduction

Herein the term "properties" is used to refer to any single piece of data that is stored within another structure and "metadata" refers to the entire collection of properties that belongs to a structure. Some additional characteristics of properties (according to the definition used in this package) are:

* They are not necessarily known at compile time (much like the elements of an array or values in a dictionary)
* They carry semantic meaning that may be shared across structures (similar to `eltype` or `ndims` for arrays)
* They may have different characteristic in different contexts (mutable/immutable in certain structures or even optionally defined)

This package was created while trying to balance the following goals:

1. Extensibility: Easy for developers to add new properties while using those previously defined
2. Usability: It shouldn't make it harder for users to access or interact with properties.
3. Optimization: It should be possible to optimize performance of accessing and setting properties without violating the first 2 goals.


[ImageMetadata.jl](https://github.com/JuliaImages/ImageMetadata.jl), [MetadataArrays.jl](https://github.com/piever/MetadataArrays.jl), and [MetaGraph.jl](https://github.com/JuliaGraphs/MetaGraphs.jl) are just a few packages that provide a way of adding metadata to array or graph structures. [FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl) allows creating methods that produce "metadata" at each field of a structure. These packages provide similar functionality but have little overlap in the core functionality used here. Therefore, this package may be seen as complementary to these.

There are some packages that have significant overlap with FieldProperties. [MacroTools.jl](https://github.com/MikeInnes/MacroTools.jl) provides `@forward` which conveniently maps method definitions to specific fields of structures. This overlaps with a great deal of what `@assignprops` does. However, `@forward` is strictly for methods (not properties) and there are some [benefits](#creating-structures-that-contain-properties) to using `@assignprops`. There are many packages aimed at metaprogramming that appear to have very similar utilities. However, FieldProperties was created because none of them appeared to accomplish all the previously mentioned goals and there wasn't a clear path forward in using them together to accomplish those goals.

## Creating Properties

Properties can be defined with varying degrees of specificity.
```julia
julia> @defprop Property1{:prop1}

# name of property. When structure has Property1 assigned to it, it can be retreived using `x.prop1`
julia> propname(Property1)
:prop1

# no default value for Property1
julia> propdefault(Property1)
NotProperty

# no type restriction for Property1
julia> proptype(Property1)
Any

# formal getter method for Property1
julia> Property1.getter
prop1 (generic function with 1 method)

# formal setter method for Property1
julia> Property1.setter
prop1! (generic function with 1 method)
```

Define a property's type
```julia
julia> @defprop Property2{:prop2}::Int

julia> propname(Property2) == :prop2
true

julia> propdefault(Property2) == NotProperty
true

julia> proptype(Property2) == Int
true

julia> Property2.getter == prop2
true

julia> Property2.setter == prop2!
true
```

Define type requirement and default value.
```julia
julia> @defprop Property3{:prop3}::Int=1

julia> propname(Property3) == :prop3
true

julia> propdefault(Property3) == 1
true

julia> proptype(Property3) == Int
true
p

julia> Property3.getter == prop3
true

julia> Property3.setter == prop3!
true
```

Define a default value but no type requirement.
```julia
julia> @defprop Property4{:prop4}=1

julia> propname(Property4) == :prop4
true

julia> propdefault(Property4) == 1
true

julia> proptype(Property4) == Any
true

julia> Property4.getter == prop4
true

julia> Property4.setter == prop4!
true
```

## Creating Structures That Contain Properties

Although properties can be used flexibly with different structures, it may be easier to take advantage of the provided `AbstractMetadata` type. In the following example we take advantage of the `Description` and `DictExtension`. These provide a method of describing a structure and an extensible pool for storing an arbitrary number of properties.

```julia
julia> mutable struct MyProperties{M} <: AbstractMetadata{M}
           my_description::String
           my_properties::M
       end

# tells other functions where to find the dictionary so there's support for dictionary methods
julia> FieldProperties.subdict(m::MyProperties) = getfield(m, :my_properties)
```

Binding `Description` and `DictExtension` to specific fields is accomplished through `@assignprops`. Several other methods specific to `MyProperties` are created to provide property like behavior. Most notably, the methods from base overwritten are `getproperty`, `setproperty!`, and `propertynames`.
```julia
julia> @assignprops(
           MyProperties,
           :my_description => Description,
           :my_properties => DictExtension)

julia> m = MyProperties("", Dict{Symbol,Any}())
MyProperties{Dict{Symbol,Any}} with 1 entry
    description:

julia> propertynames(m)
(:description,)
```

```julia
julia> FieldProperties.description(m)
""

julia> FieldProperties.description!(m, "foo")
MyProperties{Dict{Symbol,Any}} with 1 entry
    description: foo

julia> FieldProperties.description(m)
"foo"

julia> m.description = "bar"
"bar"

julia> FieldProperties.description(m)
"bar"

julia> m.description
"bar"
```

Optional properties can be assigned to the `DictExtension` using the `DictExtension(Propert1, Property2)` syntax.
```julia
julia> @defprop CalibrationMaximum{:calmax}

julia> FieldProperties.propdefault(::CalibrationMaximumType, x::AbstractArray) = maximum(x)

julia> FieldProperties.proptype(::CalibrationMaximumType, ::Type{<:AbstractArray{T,N}}) where {T,N} = T

julia> @defprop CalibrationMinimum{:calmin}

julia> FieldProperties.propdefault(::CalibrationMinimumType, x::AbstractArray) = minimum(x)

julia> FieldProperties.proptype(::CalibrationMinimumType, ::Type{<:AbstractArray{T,N}}) where {T,N} = T

julia> struct MyArray{T,N,P<:AbstractArray{T,N},M<:AbstractDict{Symbol,Any}} <: AbstractArray{T,N}
           _parent::P
           my_properties::M
       end

julia> Base.parent(m::MyArray) = getfield(m, :_parent)

julia> Base.size(m::MyArray) = size(parent(m))

julia> Base.maximum(m::MyArray) = maximum(parent(m))

julia> Base.minimum(m::MyArray) = minimum(parent(m))

julia> @assignprops(
           MyArray,
           :my_properties => DictExtension(CalibrationMaximum,CalibrationMinimum))
```
