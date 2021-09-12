import CoreGraphics

public struct CubicBezier {
    private var p1: CGPoint = .zero
    private var p2: CGPoint = .zero
    private var values: [(CGFloat, CGFloat)] = []
    private var values1: [CGFloat] = []
    private var points: Int = 50
    
    init(_ p1: CGPoint, _ p2: CGPoint){
        self.p1 = p1
        self.p2 = p2
        setup()
    }
    private var lastX: CGFloat = 0
    private var needX: CGFloat = 0
    private mutating func setup() {
        var values: [CGFloat] = []
        for i in 0...points{
            let p = getValue1(CGFloat(i) / CGFloat(points))
            setX(p.x, p.y, &values)
        }
        values1 = values
        values1.append(1)
    }
    
    private mutating func setX(_ x: CGFloat, _ y: CGFloat, _ arr: inout [CGFloat]){
        let lastY = arr.last ?? 0
        if x >= needX{
            var coof = (needX - lastX) / (x - lastX)
            if coof.isNaN{ coof = 0 }
            arr.append(lastY + ((y - lastY) * coof))
            lastX = needX
            needX += 1 / CGFloat(points)
            setX(x, y, &arr)
        }
    }
    
    func getValue(_ row: CGFloat) -> CGFloat{
        var row = row
        if row < 0 {row = 0}
        if row > 1 {row = 1}
    
        let intX = Int(row * CGFloat(points))
        let fY = values1[intX]
        if intX + 1 >= values1.count{return fY}
        let sY = values1[intX + 1]
        let coof = (row - (CGFloat(intX) / CGFloat(points))) / (1 / CGFloat(points))
        let value = fY + ((sY - fY) * coof)
        return value
    }
    
    private func getValue1(_ row: CGFloat) -> CGPoint{
        let p01 = getPointInLine(p2: p1, value: row)
        let p12 = getPointInLine(p1: p1, p2: p2, value: row)
        let p23 = getPointInLine(p1: p2, value: row)
        
        let p0112 = getPointInLine(p1: p01, p2: p12, value: row)
        let p1223 = getPointInLine(p1: p12, p2: p23, value: row)
        
        return getPointInLine(p1: p0112, p2: p1223, value: row)
    }
    
    private func getPointInLine(p1: CGPoint = .zero, p2: CGPoint = CGPoint(x: 1, y: 1), value: CGFloat) -> CGPoint{
        let square: CGSize = CGSize(width: (p1.x - p2.x) * value, height: (p1.y - p2.y) * value)
        return CGPoint(x: p1.x - square.width, y: p1.y - square.height)
    }
}
