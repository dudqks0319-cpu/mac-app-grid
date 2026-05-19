import SwiftUI

struct NewFolderSheet: View {
    @Binding var name: String
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 폴더")
                .font(.title2)
                .bold()
            TextField("폴더 이름", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("취소") {
                    onCancel()
                    dismiss()
                }
                Button("생성") {
                    onCreate(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}
