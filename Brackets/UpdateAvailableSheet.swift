//
//  UpdateAvailableSheet.swift
//  Brackets
//

import SwiftUI

struct UpdateAvailableSheet: View {
    let newVersion: String
    let onLater: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accent)

            VStack(spacing: 8) {
                Text("Actualización disponible")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Hay una nueva versión de Brackets (\(newVersion)). Actualiza para obtener las últimas mejoras.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    if let url = AppUpdateChecker.appStoreURL {
                        openURL(url)
                    }
                } label: {
                    Text("Actualizar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                }
                .buttonStyle(.plain)

                Button {
                    AppUpdateChecker.recordDismiss(version: newVersion)
                    onLater()
                } label: {
                    Text("Más tarde")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.background)
    }
}
