import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: {
        Weather.getData();
    }

    CcCard {
        RowLayout {
            spacing: 14

            MaterialSymbol {
                text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
                iconSize: 48
                color: Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Weather.data?.temp ?? "--°"
                    font.pixelSize: 30
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Weather.data?.city || Translation.tr("Location not set")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 10
        columnSpacing: 10

        WeatherCard {
            Layout.fillWidth: true
            symbol: "thermostat"
            title: Translation.tr("Feels like")
            value: Weather.data?.tempFeelsLike ?? "--°"
        }
        WeatherCard {
            Layout.fillWidth: true
            symbol: "humidity_percentage"
            title: Translation.tr("Humidity")
            value: Weather.data?.humidity ?? "--"
        }
        WeatherCard {
            Layout.fillWidth: true
            symbol: "air"
            title: Translation.tr("Wind")
            value: Weather.data?.wind ?? "--"
        }
        WeatherCard {
            Layout.fillWidth: true
            symbol: "rainy"
            title: Translation.tr("Precipitation")
            value: Weather.data?.precip ?? "--"
        }
        WeatherCard {
            Layout.fillWidth: true
            symbol: "wb_twilight"
            title: Translation.tr("Sunrise")
            value: Weather.data?.sunrise ?? "--"
        }
        WeatherCard {
            Layout.fillWidth: true
            symbol: "bedtime"
            title: Translation.tr("Sunset")
            value: Weather.data?.sunset ?? "--"
        }
    }

    Item { Layout.fillHeight: true }
}
