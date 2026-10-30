import Foundation
@main struct Checks {
    static func main() throws {
        let protected = try ProtectedSpans("已选：3000K，54W，260×80cm；ST-54W，USB-C，¥135；20件")
        assert(protected.spans == ["3000K", "54W", "260×80cm", "ST-54W", "USB-C", "¥135"])
        let restored = try protected.restore(protected.input)
        assert(restored == "已选：3000K，54W，260×80cm；ST-54W，USB-C，¥135；20件")
        do { _ = try protected.restore("[[P0]]"); assertionFailure("corruption accepted") } catch {}
        do { _ = try protected.restore(protected.input + " [[P6]]"); assertionFailure("extra placeholder accepted") } catch {}
        let rows = [
            OCRBlock(id: 0, text: "登录", rect: CGRect(x: 10,y: 10,width: 40,height: 20), observations: [0]),
            OCRBlock(id: 1, text: "注册", rect: CGRect(x: 180,y: 10,width: 40,height: 20), observations: [1]),
            OCRBlock(id: 2, text: "灯具", rect: CGRect(x: 10,y: 60,width: 40,height: 20), observations: [2]),
            OCRBlock(id: 3, text: "ST-54W", rect: CGRect(x: 60,y: 60,width: 80,height: 20), observations: [3]),
            OCRBlock(id: 4, text: "12345", rect: CGRect(x: 10,y: 100,width: 60,height: 20), observations: [4])]
        let groups = groupText(rows)
        assert(groups.count == 3 && groups[2].observations == [2,3])
        assert(Set(groups.flatMap(\.observations)).count == 4)
        let chat = groupText([
            OCRBlock(id:4,text:"您好，我收到货后发现有一个灯不",rect:CGRect(x:382,y:463,width:610,height:59),observations:[4]),
            OCRBlock(id:5,text:"亮，可以补发配件吗？",rect:CGRect(x:382,y:526,width:393,height:59),observations:[5]),
            OCRBlock(id:6,text:"可以的，麻烦拍一下故障视频，我们",rect:CGRect(x:106,y:964,width:651,height:55),observations:[6]),
            OCRBlock(id:7,text:"今天给您补发。",rect:CGRect(x:106,y:1024,width:269,height:59),observations:[7]),
            OCRBlock(id:8,text:"好的，我会拍视频，请补发安装配",rect:CGRect(x:382,y:1494,width:610,height:59),observations:[8]),
            OCRBlock(id:9,text:"件。",rect:CGRect(x:382,y:1559,width:66,height:52),observations:[9])])
        assert(chat.count == 3)
        assert(chat[0].text == "您好，我收到货后发现有一个灯不亮，可以补发配件吗？")
        assert(chat[1].text == "可以的，麻烦拍一下故障视频，我们今天给您补发。")
        assert(chat[2].text.hasSuffix("安装配件。"))
        let centered = groupText([
            OCRBlock(id:6,text:"食品用材质，防漏设计，与杯子紧密贴合，",rect:CGRect(x:324.795,y:787.866,width:678.738,height:50.134),observations:[6]),
            OCRBlock(id:7,text:"可搭配多种杯型。",rect:CGRect(x:524.526,y:837.021,width:275.112,height:47.591),observations:[7])])
        assert(centered.count == 1 && centered[0].observations == [6,7])
        let grid = groupText([
            OCRBlock(id:0,text:"独立选项标签一",rect:CGRect(x:0,y:0,width:190,height:20),observations:[0]),
            OCRBlock(id:1,text:"独立选项标签二",rect:CGRect(x:220,y:0,width:190,height:20),observations:[1]),
            OCRBlock(id:2,text:"下一行选项标签",rect:CGRect(x:0,y:25,width:190,height:20),observations:[2]),
            OCRBlock(id:3,text:"另一列选项标签",rect:CGRect(x:220,y:25,width:190,height:20),observations:[3])])
        assert(grid.count == 4)
        let buttons = groupText([
            OCRBlock(id:0,text:"登录",rect:CGRect(x:0,y:0,width:40,height:30),observations:[0]),
            OCRBlock(id:1,text:"注册",rect:CGRect(x:60,y:0,width:40,height:30),observations:[1])])
        assert(buttons.count == 2)
        assert(!containsChinese("USB-C 54W") && containsChinese("测试"))
        print("PASS: separated labels, fragment ownership, actual device chat OCR wrapping, CJK filter, exact spans, corrupt/extra placeholder rejection")
    }
}
