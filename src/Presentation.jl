
"""
```julia
Presentation(
    slides::Vector{Slide}=Slide[];
    title::String="unknown",
    author::String="unknown",
)
```

Type to contain the final presentation you want to write to .pptx.

If `isempty(slides)` then we add a first slide with the Title slide layout.

# Examples
```julia
julia> using PPTX

julia> pres = Presentation(; title = "My Presentation")

julia> slide = Slide()

julia> text = TextBox("Hello world!")

julia> push!(slide, text)

julia> push!(pres, slide)

julia> write("hello_world.pptx", pres)
```
"""
struct Presentation
    title::String
    author::String
    slides::Vector{Slide}
    function Presentation(
        slides::Vector{Slide}, author::String, title::String,
    )
        pres = new(title, author, Slide[])
        if isempty(slides)
            slides = [Slide(;title=title, layout=TITLE_SLIDE_LAYOUT)]
        end
        for slide in slides
            push!(pres, slide)
        end
        return pres
    end
end
slides(p::Presentation) = p.slides

# keyword argument constructor
function Presentation(
    slides::Vector{Slide}=Slide[];
    title::String="unknown",
    author::String="unknown",
)
    return Presentation(slides, author, title)
end

function new_rid(pres::Presentation)
    if isempty(slides(pres))
        return 6
    else
        return maximum(rid.(slides(pres))) + 1
    end
end

function Base.push!(pres::Presentation, slide::Slide)
    slide.rid = new_rid(pres)
    return push!(slides(pres), slide)
end

function make_relationships(p::Presentation)::AbstractDict
    ids = ["rId1", "rId2", "rId3", "rId4", "rId5"]
    relationship_tag_begin = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
    types = ["slideMaster", "theme", "presProps", "viewProps", "tableStyles"]
    types = relationship_tag_begin .* types
    targets = [
        "slideMasters/slideMaster1.xml",
        "theme/theme1.xml",
        "presProps.xml",
        "viewProps.xml",
        "tableStyles.xml",
    ]
    relationships = OrderedDict(
        "Relationships" => Dict[OrderedDict(
            "xmlns" => "http://schemas.openxmlformats.org/package/2006/relationships"
        )],
    )
    for (id, type, target) in Base.zip(ids, types, targets)
        push!(
            relationships["Relationships"],
            OrderedDict(
                "Relationship" =>
                    OrderedDict("Id" => id, "Type" => type, "Target" => target),
            ),
        )
    end

    for (slide_idx, slide) in enumerate(slides(p))
        slide_rel = OrderedDict(
            "Relationship" => OrderedDict(
                "Id" => "rId$(slide.rid)",
                "Type" => "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide",
                "Target" => "slides/slide$slide_idx.xml",
            ),
        )
        push!(relationships["Relationships"], slide_rel)
    end
    return relationships
end

function make_presentation(p::Presentation)
    xml_pres = OrderedDict("p:presentation" => main_attributes())
    push!(xml_pres["p:presentation"], OrderedDict("saveSubsetFonts" => "1"))

    push!(
        xml_pres["p:presentation"],
        OrderedDict(
            "p:sldMasterIdLst" => OrderedDict(
                "p:sldMasterId" => OrderedDict("id" => "2147483648", "r:id" => "rId1")
            ),
        ),
    )

    slide_id_list = Dict[]
    for (idx, slide) in enumerate(slides(p))
        push!(
            slide_id_list,
            OrderedDict(
                "p:sldId" => OrderedDict("id" => "$(idx+255)", "r:id" => "rId$(slide.rid)")
            ),
        )
    end

    push!(xml_pres["p:presentation"], OrderedDict("p:sldIdLst" => slide_id_list))

    push!(
        xml_pres["p:presentation"],
        OrderedDict("p:sldSz" => OrderedDict("cx" => "12192000", "cy" => "6858000")),
    )
    push!(
        xml_pres["p:presentation"],
        OrderedDict("p:notesSz" => OrderedDict("cx" => "6858000", "cy" => "9144000")),
    )
    return xml_pres
end