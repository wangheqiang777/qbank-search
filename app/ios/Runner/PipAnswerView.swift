import UIKit

/// 悬浮窗（PiP）里显示的答案卡片内容。
/// 由 ScanBridge 在匹配到题目后调用 configure(...) 刷新。
final class PipAnswerView: UIView {

    private let titleLabel = UILabel()
    private let answerLabel = UILabel()
    private let optionsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        layer.cornerRadius = 14
        layer.masksToBounds = true

        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor(white: 0.85, alpha: 1)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        answerLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        answerLabel.textColor = UIColor(red: 0.36, green: 0.84, blue: 0.49, alpha: 1)
        answerLabel.numberOfLines = 0

        optionsLabel.font = UIFont.systemFont(ofSize: 11)
        optionsLabel.textColor = UIColor(white: 0.8, alpha: 1)
        optionsLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, answerLabel, optionsLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        showEmpty()
    }

    func showEmpty() {
        titleLabel.text = "录屏搜题中…"
        answerLabel.text = ""
        optionsLabel.text = "正在识别屏幕上的题目"
    }

    func configure(title: String, answer: String, options: [String], highlight: Set<String>) {
        titleLabel.text = title
        answerLabel.text = answer.isEmpty ? "(未匹配到)" : answer
        if options.isEmpty {
            optionsLabel.text = ""
        } else {
            let lines = options.enumerated().map { (i, opt) -> String in
                let letter = String(Character(UnicodeScalar(65 + i)!))
                let mark = highlight.contains(letter) ? "✅ " : "    "
                return "\(mark)\(letter). \(opt)"
            }
            optionsLabel.text = lines.joined(separator: "\n")
        }
    }
}
