import Foundation

public enum VodXMLParserError: Error, LocalizedError {
    case invalidDocument

    public var errorDescription: String? { "点播 XML 响应无效" }
}

public final class VodXMLParser: NSObject, XMLParserDelegate {
    private var classes: [VodClass] = []
    private var items: [Vod] = []
    private var currentItem: Vod?
    private var currentClassID = ""
    private var currentClassName = ""
    private var currentElement = ""
    private var text = ""
    private var flag = ""
    private var playbackFrom: [String] = []
    private var playbackURLs: [String] = []

    public static func parse(_ data: Data) throws -> VodResult {
        let parser = VodXMLParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else {
            throw parser.error ?? VodXMLParserError.invalidDocument
        }
        return VodResult(classes: parser.classes, list: parser.items)
    }

    private var error: Error?

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        text = ""
        switch currentElement {
        case "ty":
            currentClassID = attributeDict["id"] ?? attributeDict["type_id"] ?? ""
        case "video":
            currentItem = Vod()
            playbackFrom = []
            playbackURLs = []
        case "dd":
            flag = attributeDict["flag"] ?? ""
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        text.append(string)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let element = elementName.lowercased()
        if element == "ty" {
            classes.append(VodClass(typeID: currentClassID, typeName: value))
        } else if element == "dd" {
            playbackFrom.append(flag)
            playbackURLs.append(value)
            flag = ""
        } else if element == "video", var item = currentItem {
            item.vodPlayFrom = playbackFrom.joined(separator: "$$$")
            item.vodPlayURL = playbackURLs.joined(separator: "$$$")
            items.append(item)
            currentItem = nil
        } else if var item = currentItem {
            apply(value: value, to: &item, key: element)
            currentItem = item
        }
        text = ""
        currentElement = ""
    }

    private func apply(value: String, to item: inout Vod, key: String) {
        switch key {
        case "id": item.vodID = value
        case "name": item.vodName = value
        case "type": item.typeName = value
        case "pic": item.vodPic = value
        case "note": item.vodRemarks = value
        case "year": item.vodYear = value
        case "area": item.vodArea = value
        case "director": item.vodDirector = value
        case "actor": item.vodActor = value
        case "des": item.vodContent = value
        default: break
        }
    }
}
