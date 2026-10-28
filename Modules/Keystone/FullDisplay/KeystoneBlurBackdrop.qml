import qs.Widgets.common

GeometryBlurBackdrop {
    property string edge: "top"
    property bool attached: false

    surfaceNamespace: "clavis-keystone-backdrop-" + (attached ? edge : "pill")
}
