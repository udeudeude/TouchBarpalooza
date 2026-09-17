import AppKit

// MARK: - DVD VIDEO idle screen

final class DVDBounceSaverView: NSView {
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var position = NSPoint(x: 31, y: 3)
    private var velocity = NSPoint(x: 52, y: 7.5)
    private var colorIndex = 0
    private let logoSize = NSSize(width: 36, height: 21.6)

    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.22, green: 0.85, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.80, alpha: 1),
        NSColor(calibratedRed: 0.97, green: 0.81, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.46, green: 0.93, blue: 0.34, alpha: 1),
        NSColor(calibratedRed: 0.58, green: 0.44, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.46, blue: 0.29, alpha: 1)
    ]

    private lazy var exactLogo: NSImage? = {
        let path = "M469.9 212.1h-14.7l-.4 2.2h6.2l-2.2 17.3h2.6l2.3-17.3h5.7zM480.1 224.9l-3.1-12.8h-1.8l-6.7 19.5h2.2l5.4-15.1 3.1 15.1 8-15.1v15.1h2.6v-19.5h-2.6zM76.2 282.1 59 249.7H44.3l27.1 49.7h8.4l27.5-49.7H92.2zM141 275.4v24h13.3v-49.7H141zM285 299.4h36.8V291h-23v-13.3h21.7v-8.5h-21.7v-11h23v-8.5H285zM472 188.1c0-18.6-105.6-33.7-236-33.7S0 169.5 0 188.1s105.7 33.7 236 33.7 236-15 236-33.7zm-298.7.5c0-6.2 24.2-11.1 54.1-11.1s54 5 54 11-24.1 11.1-54 11.1-54-5-54-11zM392.3 249.5c-19.3 0-35 11.1-35 24.8s15.7 24.8 35 24.8 35-11 35-24.8c0-13.7-15.7-24.8-35-24.8zm0 40.6c-11.5 0-20.8-7-20.8-15.8 0-8.7 9.3-15.7 20.8-15.7s20.8 7 20.8 15.7-9.3 15.8-20.8 15.8zM214.8 249.7h-21v49.7h21s33.4 0 33.4-24.6-33.4-25-33.4-25zm-7 41.2v-32.7s26.2-1.7 26.2 16.5c0 18.1-26.1 16.2-26.1 16.2zM192 54.3a78 78 0 0 0-4-26.2h1.7L234.5 154 344.5 28h59.3S450 26.8 450 56.5s-38.4 41.2-63 41.2h-10.6l13.8-59.4h-48.3l-20.4 86.4h65.8c63 0 112.8-34.6 112.8-70.4C500 1.3 418.9.6 418.9.6h-102l-64.7 81.6L227 .6H43l-6.7 27.5h61.5c8.7.2 44 2.4 44 28.4 0 29.7-38.4 41.2-62.9 41.2H68.3L82 38.3H33.7l-20.4 86.4h65.8c63 0 112.8-34.6 112.8-70.4z"
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 307'><path fill='white' fill-rule='evenodd' d='\(path)'/></svg>"
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }()

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.08, now - lastTick)
        lastTick = now
        position.x += velocity.x * CGFloat(dt)
        position.y += velocity.y * CGFloat(dt)
        let maxX = max(0, bounds.width - logoSize.width)
        let maxY = max(0, bounds.height - logoSize.height)
        var hit = false
        if position.x < 0 { position.x = -position.x; velocity.x = abs(velocity.x); hit = true }
        else if position.x > maxX { position.x = maxX - (position.x - maxX); velocity.x = -abs(velocity.x); hit = true }
        if position.y < 0 { position.y = -position.y; velocity.y = abs(velocity.y); hit = true }
        else if position.y > maxY { position.y = maxY - (position.y - maxY); velocity.y = -abs(velocity.y); hit = true }
        if hit { colorIndex = (colorIndex + 1) % colors.count }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let rect = NSRect(origin: position, size: logoSize)
        let color = colors[colorIndex]
        if let exactLogo {
            let tinted = NSImage(size: logoSize)
            tinted.lockFocus()
            exactLogo.draw(in: NSRect(origin: .zero, size: logoSize))
            color.set(); NSRect(origin: .zero, size: logoSize).fill(using: .sourceAtop)
            tinted.unlockFocus(); tinted.draw(in: rect)
        } else {
            let font = NSFont(name: "HelveticaNeue-CondensedBlackItalic", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .black)
            ("DVD" as NSString).draw(at: NSPoint(x: rect.minX + 1, y: rect.minY + 8), withAttributes: [.font: font, .foregroundColor: color])
        }
    }
}

// MARK: - Windows 3D Pipes

final class PipesSaverView: NSView {
    private struct Point3: Hashable { var x: Int; var y: Int; var z: Int }
    private enum JointKind { case elbow, ball, teapot }
    private struct Segment { var a: Point3; var b: Point3; var colorIndex: Int; var jointAtA: JointKind? }
    private struct Head { var point: Point3; var direction: Int; var colorIndex: Int }

    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var stepAccumulator: TimeInterval = 0
    private var sceneAge: TimeInterval = 0
    private var segments: [Segment] = []
    private var heads: [Head] = []
    private var starts: [(Point3, Int)] = []
    private var occupied = Set<Point3>()
    private var dissolving = false
    private var dissolveProgress: CGFloat = 0

    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.05, green: 0.63, blue: 0.53, alpha: 1),
        NSColor(calibratedRed: 0.92, green: 0.70, blue: 0.09, alpha: 1),
        NSColor(calibratedRed: 0.89, green: 0.14, blue: 0.11, alpha: 1),
        NSColor(calibratedRed: 0.73, green: 0.82, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.91, green: 0.39, blue: 0.11, alpha: 1),
        NSColor(calibratedWhite: 0.78, alpha: 1)
    ]
    private let directions = [
        Point3(x: 1, y: 0, z: 0), Point3(x: -1, y: 0, z: 0),
        Point3(x: 0, y: 1, z: 0), Point3(x: 0, y: -1, z: 0),
        Point3(x: 0, y: 0, z: 1), Point3(x: 0, y: 0, z: -1)
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); wantsLayer = true; resetScene()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func resetScene() {
        segments.removeAll(keepingCapacity: true); heads.removeAll(keepingCapacity: true)
        starts.removeAll(keepingCapacity: true); occupied.removeAll(keepingCapacity: true)
        dissolving = false; dissolveProgress = 0; sceneAge = 0; stepAccumulator = 0
        for index in 0..<Int.random(in: 4...6) {
            var point = Point3(x: Int.random(in: -10...10), y: Int.random(in: -2...2), z: Int.random(in: -8...8))
            var tries = 0
            while occupied.contains(point) && tries < 20 {
                point = Point3(x: Int.random(in: -10...10), y: Int.random(in: -2...2), z: Int.random(in: -8...8)); tries += 1
            }
            occupied.insert(point)
            heads.append(Head(point: point, direction: Int.random(in: 0..<directions.count), colorIndex: index % colors.count))
            starts.append((point, index % colors.count))
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now; sceneAge += dt
        if dissolving {
            dissolveProgress += CGFloat(dt) / 1.05
            if dissolveProgress >= 1 { resetScene() }
            needsDisplay = true; return
        }
        stepAccumulator += dt
        while stepAccumulator >= 0.15 {
            stepAccumulator -= 0.15
            for index in heads.indices { extendPipe(index) }
        }
        if segments.count > 520 || sceneAge > 55 || heads.isEmpty { dissolving = true }
        needsDisplay = true
    }

    private func extendPipe(_ index: Int) {
        guard heads.indices.contains(index) else { return }
        let head = heads[index]; let reverse = opposite(of: head.direction)
        var choices = Array(0..<directions.count); choices.removeAll { $0 == reverse }
        if Int.random(in: 0..<100) < 56, let currentIndex = choices.firstIndex(of: head.direction) {
            let current = choices.remove(at: currentIndex); choices.shuffle(); choices.insert(current, at: 0)
        } else { choices.shuffle() }
        var chosenDirection: Int?; var nextPoint: Point3?
        for direction in choices {
            let candidate = moved(head.point, direction: direction)
            if inside(candidate) && !occupied.contains(candidate) { chosenDirection = direction; nextPoint = candidate; break }
        }
        guard let newDirection = chosenDirection, let next = nextPoint else { return }
        var joint: JointKind?
        if newDirection != head.direction {
            if Int.random(in: 0..<100) == 0 { joint = .teapot }
            else if Int.random(in: 0..<3) == 0 { joint = .ball }
            else { joint = .elbow }
        }
        segments.append(Segment(a: head.point, b: next, colorIndex: head.colorIndex, jointAtA: joint))
        occupied.insert(next); heads[index].point = next; heads[index].direction = newDirection
    }

    private func moved(_ p: Point3, direction: Int) -> Point3 { let s = directions[direction]; return Point3(x: p.x+s.x, y: p.y+s.y, z: p.z+s.z) }
    private func opposite(of d: Int) -> Int { [1,0,3,2,5,4][d] }
    private func inside(_ p: Point3) -> Bool { (-11...11).contains(p.x) && (-3...3).contains(p.y) && (-9...9).contains(p.z) }

    private func projected(_ p: Point3) -> (point: NSPoint, scale: CGFloat, depth: CGFloat) {
        let angle: CGFloat = 0.54, x = CGFloat(p.x), z = CGFloat(p.z)
        let rx = x*cos(angle)+z*sin(angle), rz = -x*sin(angle)+z*cos(angle)
        let s = 1.0 / max(0.58, 1.0 + (rz + 11) * 0.025)
        return (NSPoint(x: bounds.midX + rx*24*s, y: bounds.midY + CGFloat(p.y)*5.5*s + rz*0.10), s, rz)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        for segment in segments.sorted(by: { (projected($0.a).depth + projected($0.b).depth) > (projected($1.a).depth + projected($1.b).depth) }) { drawSegment(segment) }
        for (p,c) in starts { drawBall(at: p, color: colors[c % colors.count], multiplier: 0.85) }
        for h in heads { drawBall(at: h.point, color: colors[h.colorIndex % colors.count], multiplier: 0.95) }
        if dissolving { drawDissolveOverlay() }
    }

    private func drawSegment(_ segment: Segment) {
        let a = projected(segment.a), b = projected(segment.b), s = (a.scale+b.scale)*0.5, color = colors[segment.colorIndex % colors.count]
        let shadow = NSBezierPath(); shadow.move(to: NSPoint(x:a.point.x+0.8,y:a.point.y-0.8)); shadow.line(to:NSPoint(x:b.point.x+0.8,y:b.point.y-0.8)); shadow.lineWidth=4.8*s; NSColor(calibratedWhite:0.05,alpha:1).setStroke(); shadow.stroke()
        let pipe = NSBezierPath(); pipe.move(to:a.point); pipe.line(to:b.point); pipe.lineWidth=3.25*s; color.setStroke(); pipe.stroke()
        let hi = NSBezierPath(); hi.move(to:NSPoint(x:a.point.x-0.55,y:a.point.y+0.55)); hi.line(to:NSPoint(x:b.point.x-0.55,y:b.point.y+0.55)); hi.lineWidth=max(0.5,0.68*s); NSColor(calibratedWhite:1,alpha:0.60).setStroke(); hi.stroke()
        guard let joint = segment.jointAtA else { return }
        switch joint { case .elbow: drawBall(at: segment.a, color: color, multiplier:0.72); case .ball: drawBall(at: segment.a, color:color, multiplier:1.20); case .teapot: drawTeapot(at: segment.a, color:color) }
    }

    private func drawBall(at p: Point3, color: NSColor, multiplier: CGFloat) {
        let q=projected(p), d=4.4*q.scale*multiplier, r=NSRect(x:q.point.x-d/2,y:q.point.y-d/2,width:d,height:d)
        NSColor(calibratedWhite:0.05,alpha:1).setFill(); NSBezierPath(ovalIn:r.offsetBy(dx:0.65,dy:-0.65)).fill(); color.setFill(); NSBezierPath(ovalIn:r).fill()
        NSColor(calibratedWhite:1,alpha:0.52).setFill(); NSBezierPath(ovalIn:NSRect(x:r.minX+d*0.17,y:r.maxY-d*0.38,width:d*0.28,height:d*0.22)).fill()
    }

    private func drawTeapot(at p: Point3, color: NSColor) {
        let q=projected(p), s=max(0.72,q.scale), c=q.point; color.setFill(); color.setStroke()
        NSBezierPath(ovalIn:NSRect(x:c.x-5.2*s,y:c.y-3*s,width:10.4*s,height:6*s)).fill(); NSRect(x:c.x-2.3*s,y:c.y+2.6*s,width:4.6*s,height:1.2*s).fill()
        let sp=NSBezierPath(); sp.move(to:NSPoint(x:c.x+3.5*s,y:c.y+1*s)); sp.line(to:NSPoint(x:c.x+8*s,y:c.y+3*s)); sp.line(to:NSPoint(x:c.x+5.5*s,y:c.y-0.5*s)); sp.close(); sp.fill()
        let handle=NSBezierPath(); handle.appendArc(withCenter:NSPoint(x:c.x-4.5*s,y:c.y+0.4*s),radius:3.1*s,startAngle:70,endAngle:290,clockwise:true); handle.lineWidth=1.25*s; handle.stroke()
    }

    private func drawDissolveOverlay() {
        NSColor.black.setFill(); let columns=33, rows=3, total=columns*rows, visible=min(total,Int(CGFloat(total)*dissolveProgress)); let cw=bounds.width/CGFloat(columns), ch=bounds.height/CGFloat(rows)
        for index in 0..<visible { let n=(index*37+11)%total, x=n%columns, y=n/columns; NSRect(x:CGFloat(x)*cw,y:CGFloat(y)*ch,width:ceil(cw)+1,height:ceil(ch)+1).fill() }
    }
}

// MARK: - After Dark 2.0 Flying Toasters

final class FlyingToastersSaverView: NSView {
    private enum Kind { case toaster, toast }
    private struct Flyer { var kind: Kind; var x: CGFloat; var y: CGFloat; var speed: CGFloat; var scale: CGFloat; var phase: CGFloat }
    private var flyers:[Flyer]=[]; private var timer:Timer?; private var lastTick=ProcessInfo.processInfo.systemUptime; private var elapsed:CGFloat=0
    override var intrinsicContentSize:NSSize { NSSize(width:660,height:30) }
    override init(frame:NSRect){ super.init(frame:frame); wantsLayer=true; seedFlyers(); let t=Timer(timeInterval:1.0/30.0,repeats:true){[weak self]_ in self?.tick()}; timer=t; RunLoop.main.add(t,forMode:.common) }
    required init?(coder:NSCoder){ fatalError("init(coder:) has not been implemented") }
    deinit{timer?.invalidate()}

    private func seedFlyers(){
        flyers.removeAll()
        for i in 0..<8 { flyers.append(Flyer(kind:.toaster,x:CGFloat(i)*96+35,y:CGFloat(8+(i*11)%27),speed:CGFloat(17+(i*3)%10),scale:[0.72,0.80,0.88,0.96][i%4],phase:CGFloat(i)*0.73)) }
        for i in 0..<5 { flyers.append(Flyer(kind:.toast,x:CGFloat(i)*142+90,y:CGFloat(4+(i*9)%25),speed:CGFloat(16+i*2),scale:CGFloat(0.74+Double(i%3)*0.08),phase:CGFloat(i)*0.91)) }
    }

    private func tick(){
        let now=ProcessInfo.processInfo.systemUptime, dt=min(0.1,now-lastTick); lastTick=now; elapsed += CGFloat(dt)
        for i in flyers.indices {
            let d=flyers[i].speed*CGFloat(dt); flyers[i].x -= d; flyers[i].y -= d
            let w=(flyers[i].kind == .toaster ? 34:12)*flyers[i].scale, h=(flyers[i].kind == .toaster ? 22:8)*flyers[i].scale
            if flyers[i].x < -w { flyers[i].x=bounds.width+CGFloat.random(in:0...120) }
            if flyers[i].y < -h { flyers[i].y=bounds.height+CGFloat.random(in:0...30) }
        }
        needsDisplay=true
    }

    override func draw(_ dirtyRect:NSRect){ NSColor.black.setFill(); dirtyRect.fill(); for f in flyers { if f.kind == .toaster { drawToaster(f) } else { drawToast(f) } } }

    private func drawToaster(_ f:Flyer){
        let s=f.scale,x=floor(f.x),y=floor(f.y),frame=Int((elapsed*7.5+f.phase).rounded(.down))%4
        let dark=NSColor(calibratedRed:0.10,green:0.12,blue:0.11,alpha:1), olive=NSColor(calibratedRed:0.33,green:0.39,blue:0.28,alpha:1), metal=NSColor(calibratedRed:0.76,green:0.80,blue:0.79,alpha:1), bright=NSColor(calibratedWhite:0.96,alpha:1), red=NSColor(calibratedRed:0.82,green:0.10,blue:0.06,alpha:1)
        bright.setFill(); let far=NSBezierPath(); far.move(to:NSPoint(x:x+7*s,y:y+12*s)); far.curve(to:NSPoint(x:x+12*s,y:y+19*s),controlPoint1:NSPoint(x:x+6*s,y:y+17*s),controlPoint2:NSPoint(x:x+10*s,y:y+20*s)); far.line(to:NSPoint(x:x+13*s,y:y+13*s)); far.close(); far.fill()
        olive.setFill(); let side=NSBezierPath(); side.move(to:NSPoint(x:x+2*s,y:y+3*s)); side.line(to:NSPoint(x:x+7*s,y:y+1*s)); side.line(to:NSPoint(x:x+7*s,y:y+13*s)); side.line(to:NSPoint(x:x+2*s,y:y+11*s)); side.close(); side.fill()
        metal.setFill(); NSBezierPath(roundedRect:NSRect(x:x+5*s,y:y+2*s,width:17*s,height:12*s),xRadius:4*s,yRadius:4*s).fill()
        bright.setFill(); let top=NSBezierPath(); top.move(to:NSPoint(x:x+7*s,y:y+12*s)); top.line(to:NSPoint(x:x+20*s,y:y+12*s)); top.line(to:NSPoint(x:x+17*s,y:y+15*s)); top.line(to:NSPoint(x:x+8*s,y:y+15*s)); top.close(); top.fill()
        dark.setFill(); NSRect(x:x+9*s,y:y+13.1*s,width:8*s,height:0.9*s).fill(); NSRect(x:x+10*s,y:y+11.6*s,width:8*s,height:0.8*s).fill(); red.setFill(); NSRect(x:x+2.2*s,y:y+6.2*s,width:1.8*s,height:1.8*s).fill()
        drawWing(at:NSPoint(x:x+20*s,y:y+8*s),scale:s,frame:frame)
    }

    private func drawWing(at root:NSPoint,scale s:CGFloat,frame:Int){
        let lift:[CGFloat]=[4.0,0.8,-2.7,0.4], l=lift[frame]; NSColor(calibratedWhite:0.97,alpha:1).setFill(); let p=NSBezierPath(); p.move(to:root)
        p.curve(to:NSPoint(x:root.x+7*s,y:root.y+(5+l)*s),controlPoint1:NSPoint(x:root.x+2*s,y:root.y+(4+l)*s),controlPoint2:NSPoint(x:root.x+5*s,y:root.y+(6+l)*s))
        p.curve(to:NSPoint(x:root.x+12*s,y:root.y+(2.5+l*0.7)*s),controlPoint1:NSPoint(x:root.x+10*s,y:root.y+(6+l)*s),controlPoint2:NSPoint(x:root.x+13*s,y:root.y+(5+l)*s))
        p.curve(to:NSPoint(x:root.x+8*s,y:root.y-(1.5-l*0.20)*s),controlPoint1:NSPoint(x:root.x+11*s,y:root.y+0.5*s),controlPoint2:NSPoint(x:root.x+10*s,y:root.y-1.5*s)); p.curve(to:root,controlPoint1:NSPoint(x:root.x+5*s,y:root.y-2.5*s),controlPoint2:NSPoint(x:root.x+2*s,y:root.y-1*s)); p.close(); p.fill()
    }

    private func drawToast(_ f:Flyer){
        let s=f.scale,x=floor(f.x),y=floor(f.y), crust=NSColor(calibratedRed:0.58,green:0.28,blue:0.07,alpha:1), bread=NSColor(calibratedRed:0.94,green:0.68,blue:0.25,alpha:1)
        crust.setFill(); let o=NSBezierPath(); o.move(to:NSPoint(x:x+1*s,y:y+1*s)); o.line(to:NSPoint(x:x+9*s,y:y)); o.line(to:NSPoint(x:x+11*s,y:y+4.5*s)); o.line(to:NSPoint(x:x+8*s,y:y+7*s)); o.line(to:NSPoint(x:x+2*s,y:y+6.2*s)); o.close(); o.fill()
        bread.setFill(); let i=NSBezierPath(); i.move(to:NSPoint(x:x+2.2*s,y:y+1.7*s)); i.line(to:NSPoint(x:x+8.2*s,y:y+1*s)); i.line(to:NSPoint(x:x+9.6*s,y:y+4.2*s)); i.line(to:NSPoint(x:x+7.3*s,y:y+5.7*s)); i.line(to:NSPoint(x:x+2.8*s,y:y+5.1*s)); i.close(); i.fill()
    }
}
