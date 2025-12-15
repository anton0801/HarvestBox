
import SwiftUI

struct AddCategoryView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
  
    @State private var name = ""
    @State private var icon = "📌"
    @State private var selectedColor = Color(hex: "6B6B6B")
  
    var body: some View {
        NavigationView {
            Form {
                TextField("Category name", text: $name)
                TextField("Icon (emoji)", text: $icon)
                    .frame(maxWidth: 80)
                ColorPicker("Color", selection: $selectedColor)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let hex = selectedColor.toHex ?? "6B6B6B"
                        let newCat = Category(name: name, icon: icon, colorHex: hex)
                        manager.categories.append(newCat)
                        manager.saveCategories()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || icon.isEmpty)
                }
            }
        }
    }
}



struct HarvestInitScreen: View {
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                if isLandscape {
                    Image("splash_loading_back_landscape")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("splash_loading_back")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                }
                
                VStack {
                    if isLandscape {
                        HStack {
                            Image("ic_logo_with_loading")
                                .resizable()
                                .frame(width: 350, height: 350)
                                .padding(.bottom, 24)
                                .padding(.leading)
                            Spacer()
                            
                        }
                    } else {
                        Image("ic_logo_with_loading")
                            .resizable()
                            .frame(width: 400, height: 400)
                            .padding(.top, 52)
                        HarvestProgressView()
                            .frame(width: 230)
                            .padding(.bottom, 32)
                        Spacer()
                    }
                }
                
                if isLandscape {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HarvestProgressView()
                                .frame(width: 230)
                                .padding(.bottom)
                                .padding(.trailing)
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

