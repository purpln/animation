import UIKit

public class AnimationCurve {
    func curveAction(_ value: CGFloat) -> CGFloat { value }
    
    public class var standart: AnimationCurve { AnimationCurve() }
    public class var ezDown: AnimationCurve { AnimationCurveEzDown() }
    public class func custom(_ action: @escaping (_ value: CGFloat) -> CGFloat) -> AnimationCurve { AnimationCurveCustom(action) }
    public class func bezier(_ p1: CGPoint, _ p2: CGPoint) -> AnimationCurve {
        let curve = CubicBezier(p1, p2)
        return .custom { curve.getValue($0) }
    }
}

public class AnimationCurveEzDown: AnimationCurve {
    override func curveAction(_ value: CGFloat) -> CGFloat {(2 - (1 * value)) * value}
}

public class AnimationReverstCurve: AnimationCurve {
    var curve: AnimationCurve
    init(_ curve: AnimationCurve) { self.curve = curve }
    override func curveAction(_ value: CGFloat) -> CGFloat { 1 - curve.curveAction(value) }
}

public class AnimationCurveCustom: AnimationCurve {
    private var action: (_ value: CGFloat) -> CGFloat = {$0}
    
    init(_ action: @escaping (_ value: CGFloat) -> CGFloat){ self.action = action }
    override func curveAction(_ value: CGFloat) -> CGFloat { action(value) }
}

public class AnimationAction {
    private var flow: AnimationAction?
    public func start(){ isActive = true; flow?.start() }
    public func pause(){ isActive = false; flow?.pause() }
    public func restart(){ isEnd = false; flow?.restart() }
    fileprivate func reverse(){flow?.restart()}
    
    fileprivate var endBlock: ()->() = {}
    fileprivate(set) var isActive: Bool = false
    fileprivate(set) var isEnd:    Bool = false
    fileprivate(set) var duration: TimeInterval = 0
    
    public init() {}
    public init(_ flow: AnimationAction) {
        self.flow = flow
        
        duration = flow.duration
        flow.endBlock = {[weak self] in self?.isEnd = true }
    }
    
    public class func delay(duration: TimeInterval) -> AnimationAction{
        .animation(duration: duration, animation: {_ in})
    }
    public class func action(_ action: @escaping ()->() = {}) -> AnimationAction{
        .animation(duration: 0, animation: {_ in action()})
    }
    public class func reverse(_ animation: AnimationAction) -> AnimationAction{
        animation.reverse()
        return animation
    }
    public class func animation(
        duration: TimeInterval,
        curve: AnimationCurve = .standart,
        animation: @escaping (CGFloat)->()
    ) -> AnimationAction{
        AnimationCustomAction(duration: duration, curve: curve, animation: animation)
    }
    public class func animation(
        duration: TimeInterval,
        curve: AnimationCurve = .standart,
        animation: @escaping (CGFloat, TimeInterval)->()
    ) -> AnimationAction{
        AnimationCustomAction(duration: duration, curve: curve, animation: animation)
    }
    
    public class func loop(count: Int, _ animation: AnimationAction) -> AnimationAction{
        AnimationActionLoop(count: count, animation: animation)
    }
    public class func infinityLoop(_ animation: AnimationAction) -> AnimationAction{
        AnimationActionLoop(animation: animation)
    }
    
    public class func group(_ animations: [AnimationAction]) -> AnimationAction{
        var duration: TimeInterval = 0
        animations.forEach{ if duration < $0.duration{ duration = $0.duration } }
        var newAnimateArr = [AnimationAction]()
        for animation in animations{
            if animation.duration < duration{
                newAnimateArr.append(.queue([animation, .delay(duration: duration - animation.duration)]))
            }else{
                newAnimateArr.append(animation)
            }
        }
        return AnimationActionGroup(animations: newAnimateArr)
    }
    
    public class func queue(_ animations: [AnimationAction]) -> AnimationAction{
        AnimationActionQueue(animations: animations)
    }
}

fileprivate class AnimationCustomAction: AnimationAction{
    override func start() {isActive = true; setAnimator()}
    override func pause() {isActive = false; removeAnimator()}
    override func restart() {
        isEnd = false
        currentTime = 0
        startTime = CACurrentMediaTime()
    }
    override func reverse() {curve = AnimationReverstCurve(curve)}
    
    private var animationBlock: (CGFloat, TimeInterval)->() = {_, _ in}
    private var curve: AnimationCurve = .standart
    
    
    private var startTime: TimeInterval = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var currentState: CGFloat = 0
    
    private var animator: CADisplayLink?
    
    private func setAnimator(){
        startTime = CACurrentMediaTime() - currentTime
        animator = CADisplayLink(target: self, selector: #selector(update))
        animator?.add(to: RunLoop.main, forMode: .common)
    }
    private func removeAnimator(){
        animator?.invalidate()
        animator = nil
    }
    
    @objc func update(){
        let time = CACurrentMediaTime()
        currentTime = time - startTime
        let state = CGFloat(currentTime / duration)
        currentState = curve.curveAction(state)
        if state >= 1{
            isEnd = true
            animationBlock(curve.curveAction(1), currentTime)
            pause()
            endBlock()
        }else{
            animationBlock(currentState, currentTime)
        }
    }
    
    convenience init(
        duration: TimeInterval,
        curve: AnimationCurve = .standart,
        animation: @escaping (CGFloat)->()
    ) {
        self.init(duration: duration, curve: curve, animation: {value, _ in animation(value)})
    }
    
    init(
        duration: TimeInterval,
        curve: AnimationCurve = .standart,
        animation: @escaping (CGFloat, TimeInterval)->()
    ) {
        super.init()
        self.duration = duration
        self.curve = curve
        self.animationBlock = animation
    }
}

fileprivate class AnimationActionLoop: AnimationAction{
    private var count = 0
    private var counter = 1
    private var animation: AnimationAction
    override func reverse() {animation.reverse()}
    
    override func start() {isActive = true; animation.start()}
    override func pause() {isActive = false; animation.pause()}
    override func restart() {
        isEnd = false
        counter = 0
        animation.restart()
    }
    
    private func update(){
        if count > 0{
            if counter >= count{
                isEnd = true
                pause()
                endBlock()
                return
            }else{
                counter += 1
            }
        }
        animation.restart()
        animation.start()
    }
    
    init(count: Int = 0, animation: AnimationAction) {
        self.animation = animation
        super.init()
        
        self.count = count >= 0 ? count : 0
        duration = animation.duration * Double(count)
        self.animation.endBlock = {[weak self] in self?.update() }
    }
}

fileprivate class AnimationActionQueue: AnimationAction{
    private var animations = [AnimationAction]()
    private var activeAnimation: AnimationAction?
    private var activeAnimationNumber: Int = 0
    
    override func start() {
        isActive = true
        activeAnimation?.start()
    }
    override func pause() {
        isActive = false
        activeAnimation?.pause()
    }
    override func restart() {
        isEnd = false
        activeAnimation?.pause()
        animations.forEach{$0.restart()}
        activeAnimationNumber = 0
        activeAnimation = animations.first
        if isActive {activeAnimation?.start()}
    }
    override func reverse() {
        for animation in animations { animation.reverse() }
        animations = animations.reversed()
        activeAnimation = animations.first
    }
    
    
    init(animations: [AnimationAction]){
        self.animations = animations
        super.init()
        
        animations.forEach{duration += $0.duration}
        self.activeAnimation = animations.first
        for animation in self.animations{
            animation.endBlock = {[weak self] in self?.next()}
        }
    }
    
    private func next(){
        if activeAnimationNumber >= self.animations.count - 1{
            isEnd = true
            pause()
            endBlock()
        }else{
            activeAnimationNumber += 1
            activeAnimation = animations[activeAnimationNumber]
            if isActive == true{ activeAnimation?.start() }
        }
    }
}

fileprivate class AnimationActionGroup: AnimationAction{
    private var animations = [AnimationAction]()
    
    override func start() {
        isActive = true
        animations.forEach{ if !$0.isEnd {$0.start()} }
    }
    override func pause() {
        isActive = false
        animations.forEach{ if $0.isActive {$0.pause()} }
    }
    override func restart() {
        isEnd = false
        animations.forEach{
            $0.restart()
            if self.isActive && !$0.isActive { $0.start() }
        }
    }
    override func reverse() {
        for animation in animations { animation.reverse() }
    }
    
    init(animations: [AnimationAction]){
        self.animations = animations
        super.init()
        animations.forEach{ if duration < $0.duration{ duration = $0.duration } }
        for animation in self.animations{
            animation.endBlock = {[weak self] in
                for animation in self?.animations ?? []{ if !animation.isEnd {return} }
                self?.pause()
                self?.endBlock()
            }
        }
    }
    
}
