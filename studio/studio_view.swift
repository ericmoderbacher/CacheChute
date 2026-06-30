// studio_view — native macOS desktop window for inspecting a studio run.
// Centerpiece: SEE HOW THE IMAGE IS SEGMENTED — the source with every candidate mask
// overlaid in its own color, plus a legend table (IoU / area / chosen) so you can tell
// what's what. Reads a run dir (out/<NAME>/) produced by pipeline.sh.
//
//   studio_view [RUN_DIR]      (default: out/fastener)
import Cocoa
import SwiftUI

extension NSImage {
    var pixelSize: CGSize {
        if let r = representations.first as? NSBitmapImageRep {
            return CGSize(width: r.pixelsWide, height: r.pixelsHigh)
        }
        return size
    }
}

struct MaskInfo { let index: Int; let image: NSImage; let iou: Double; let area: Int; let chosen: Bool }

struct Run {
    let dir: URL
    let source: NSImage?
    let masks: [MaskInfo]
    let views: [NSImage]
    let box: CGRect?
    let label: String
    let imageSize: CGSize
}

func loadRun(_ path: String) -> Run {
    let dir = URL(fileURLWithPath: path)
    func img(_ name: String) -> NSImage? {
        let u = dir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: u.path) ? NSImage(contentsOf: u) : nil
    }
    let source = img("source.png") ?? img("input.png")

    // mask metadata (masks.tsv: idx \t iou \t area \t chosen)
    var metas: [Int: (Double, Int, Bool)] = [:]
    if let s = try? String(contentsOf: dir.appendingPathComponent("masks.tsv"), encoding: .utf8) {
        for line in s.split(separator: "\n").dropFirst() {
            let c = line.split(separator: "\t")
            if c.count >= 4, let idx = Int(c[0]) { metas[idx] = (Double(c[1]) ?? 0, Int(c[2]) ?? 0, c[3] == "1") }
        }
    }
    var masks: [MaskInfo] = []
    for i in 0..<8 {
        if let im = img("mask_\(i).png") {
            let m = metas[i] ?? (0, 0, false)
            masks.append(MaskInfo(index: i, image: im, iou: m.0, area: m.1, chosen: m.2))
        }
    }
    if masks.isEmpty, let single = img("mask.png") {   // back-compat: a single chosen mask
        masks.append(MaskInfo(index: 0, image: single, iou: 0, area: 0, chosen: true))
    }

    var views: [NSImage] = []
    for i in 0..<6 { if let v = img("view_\(i).png") { views.append(v) } }

    var box: CGRect? = nil; var label = ""
    if let s = try? String(contentsOf: dir.appendingPathComponent("box.txt"), encoding: .utf8) {
        let toks = s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
        let nums = toks.compactMap { Double($0) }
        if nums.count >= 4 { box = CGRect(x: nums[0], y: nums[1], width: nums[2]-nums[0], height: nums[3]-nums[1]) }
        if let last = toks.last, Double(last) == nil { label = last }
    }
    let isz = source?.pixelSize ?? masks.first?.image.pixelSize ?? CGSize(width: 1, height: 1)
    return Run(dir: dir, source: source, masks: masks, views: views, box: box, label: label, imageSize: isz)
}

func maskColor(_ i: Int) -> Color {
    let base: [Color] = [Color(red: 1.0, green: 0.30, blue: 0.32),
                         Color(red: 0.35, green: 0.85, blue: 0.45),
                         Color(red: 0.35, green: 0.62, blue: 1.0)]
    if i < base.count { return base[i] }
    return Color(hue: (Double(i) * 0.13).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.95)
}

func aspectFit(_ image: CGSize, into container: CGSize) -> CGRect {
    guard image.width > 0, image.height > 0 else { return .zero }
    let s = min(container.width / image.width, container.height / image.height)
    let w = image.width * s, h = image.height * s
    return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
}

struct SegmentationView: View {
    let run: Run
    @State private var visible: [Bool]
    @State private var maskOpacity: Double = 0.5
    @State private var showBox = false

    init(run: Run) {
        self.run = run
        _visible = State(initialValue: Array(repeating: true, count: max(1, (run.masks.map { $0.index }.max() ?? 0) + 1)))
    }

    private var totalPixels: Double { max(1, Double(run.imageSize.width * run.imageSize.height)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Object Studio · segmentation").font(.headline)
                Spacer()
                Text("\(run.masks.count) candidate masks · \(run.dir.lastPathComponent)")
                    .foregroundColor(.secondary).font(.callout)
            }.padding(10)

            GeometryReader { geo in
                let fit = aspectFit(run.imageSize, into: geo.size)
                ZStack(alignment: .topLeading) {
                    if let src = run.source {
                        Image(nsImage: src).resizable().scaledToFit()
                    }
                    ForEach(run.masks, id: \.index) { mk in
                        if mk.index < visible.count && visible[mk.index] {
                            Image(nsImage: mk.image).resizable().scaledToFit()
                                .colorMultiply(maskColor(mk.index)).blendMode(.screen).opacity(maskOpacity)
                        }
                    }
                    if showBox, let b = run.box, run.imageSize.width > 0 {
                        let sx = fit.width / run.imageSize.width
                        let r = CGRect(x: fit.minX + b.minX*sx, y: fit.minY + b.minY*sx, width: b.width*sx, height: b.height*sx)
                        Rectangle().stroke(Color.yellow, lineWidth: 1.5)
                            .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                    }
                }.frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black).frame(minHeight: 360)

            HStack(spacing: 14) {
                Text("overlay opacity").font(.caption).foregroundColor(.secondary)
                Slider(value: $maskOpacity, in: 0...1).frame(width: 160)
                Toggle("prompt box", isOn: $showBox).disabled(run.box == nil)
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 8)

            Divider()
            // legend / table — one row per candidate mask
            VStack(alignment: .leading, spacing: 2) {
                ForEach(run.masks, id: \.index) { mk in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { mk.index < visible.count ? visible[mk.index] : true },
                            set: { if mk.index < visible.count { visible[mk.index] = $0 } })).labelsHidden()
                        RoundedRectangle(cornerRadius: 3).fill(maskColor(mk.index)).frame(width: 16, height: 16)
                        Text("mask \(mk.index)").frame(width: 60, alignment: .leading)
                        Text(String(format: "IoU %.3f", mk.iou)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                        Text(String(format: "%.1f%% of frame", 100.0 * Double(mk.area) / totalPixels))
                            .foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                        if mk.chosen { Text("★ chosen").foregroundColor(.yellow).font(.caption.bold()) }
                        Spacer()
                    }.font(.callout)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)

            if !run.views.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(run.views.enumerated()), id: \.offset) { _, v in
                            Image(nsImage: v).resizable().scaledToFit().frame(height: 80).border(Color.gray.opacity(0.5))
                        }
                    }
                }.frame(height: 88).padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .frame(minWidth: 820, minHeight: 640)
        .background(Color(white: 0.07))
    }
}

let runPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out/fastener"
let run = loadRun(runPath)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 960, height: 820),
    styleMask: [.titled, .closable, .resizable, .miniaturizable],
    backing: .buffered, defer: false)
window.title = "Object Studio — \(run.dir.lastPathComponent)"
window.center()
window.contentView = NSHostingView(rootView: SegmentationView(run: run))
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
