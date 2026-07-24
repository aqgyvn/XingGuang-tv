import Foundation

public enum PreviewFixtures {
    public static let config: VodConfigDocument = {
        guard let url = Bundle.module.url(forResource: "preview-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(VodConfigDocument.self, from: data) else {
            return VodConfigDocument(sites: [Site(key: "preview", name: "星光预览", type: 1)])
        }
        return config
    }()

    public static var site: Site {
        config.sites.first ?? Site(key: "preview", name: "星光预览", type: 1)
    }

    public static let categories: [VodClass] = [
        VodClass(typeID: "all", typeName: "全部"),
        VodClass(typeID: "movie", typeName: "电影"),
        VodClass(typeID: "series", typeName: "剧集"),
        VodClass(typeID: "variety", typeName: "综艺"),
        VodClass(typeID: "anime", typeName: "动漫")
    ]

    public static let vods: [Vod] = [
        Vod(vodID: "1", vodName: "少侠逆袭攻略", typeName: "剧集", vodRemarks: "全26集", vodYear: "2026", vodContent: "少年踏上旅程，在选择与成长中寻找自己的答案。"),
        Vod(vodID: "2", vodName: "胶囊计划奇迹", typeName: "动漫", vodRemarks: "更新至3集", vodYear: "2026", vodContent: "风格各异的动画短片合集。"),
        Vod(vodID: "3", vodName: "京城奇探", typeName: "剧集", vodRemarks: "更新至25集", vodYear: "2026", vodContent: "发生在古城中的连环谜案。"),
        Vod(vodID: "4", vodName: "快乐老家", typeName: "综艺", vodRemarks: "更新至0621", vodYear: "2026", vodContent: "朋友们共同完成一场轻松的旅行。"),
        Vod(vodID: "5", vodName: "短剧新场", typeName: "短剧", vodRemarks: "全26集", vodYear: "2026", vodContent: "紧凑明快的都市故事。"),
        Vod(vodID: "6", vodName: "海岛来信", typeName: "电影", vodRemarks: "1080P", vodYear: "2025", vodContent: "一封旧信串起跨越多年的相遇。")
    ]

    public static let history: History = {
        var item = History(key: "preview@@@2", vodName: "胶囊计划奇迹")
        item.vodRemarks = "第3集"
        item.position = 1_320_000
        item.duration = 2_700_000
        return item
    }()

    public static let keeps: [Keep] = [
        Keep(key: "preview@@@1", siteName: site.name, vodName: vods[0].vodName),
        Keep(key: "preview@@@3", siteName: site.name, vodName: vods[2].vodName)
    ]
}
