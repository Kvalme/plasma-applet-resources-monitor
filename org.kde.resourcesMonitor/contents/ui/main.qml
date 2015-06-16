/*
 * Copyright 2015  Martin Kotelnik <clearmartin@seznam.cz>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */
import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kio 1.0 as Kio

Item {
    id: main
    
    property bool vertical: (plasmoid.formFactor == PlasmaCore.Types.Vertical)
    
    property bool verticalLayout: plasmoid.configuration.verticalLayout
    property bool showCpuMonitor: plasmoid.configuration.showCpuMonitor
    property bool showClock: plasmoid.configuration.showClock
    property bool showRamMonitor: plasmoid.configuration.showRamMonitor
    
    property int itemMargin: 5
    property int itemWidth:  vertical ? ( verticalLayout ? parent.width : (parent.width - itemMargin) / 2 ) : ( verticalLayout ? (parent.height - itemMargin) / 2 : parent.height )
    property int itemHeight: itemWidth
    property double fontPointSize: itemHeight * 0.2
    property int graphGranularity: 20
    
    property color warningColor: Qt.tint(theme.textColor, '#60FF0000')
    property var textFontFamily: theme.defaultFont.family
    
    Layout.minimumWidth: Layout.maximumWidth
    Layout.minimumHeight: Layout.maximumHeight
    
    Layout.maximumWidth:  showCpuMonitor && showRamMonitor && !verticalLayout ? itemWidth*2 + itemMargin : itemWidth
    Layout.maximumHeight: showCpuMonitor && showRamMonitor &&  verticalLayout ? itemWidth*2 + itemMargin : itemWidth
    
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation
    
    anchors.fill: parent
    
    Kio.KRun {
        id: kRun
    }
    
    // We need to get the full path to KSysguard to be able to run it
    PlasmaCore.DataSource {
        id: apps
        engine: "apps"
        connectedSources: ["ksysguard.desktop"]
    }

    PlasmaCore.DataSource {
        id: dataSource
        engine: "systemmonitor"

        property string cpuSystem: "cpu/system/"
        property string averageClock: cpuSystem + "AverageClock"
        property string totalLoad: cpuSystem + "TotalLoad"
        property string memPhysical: "mem/physical/"
        property string memFree: memPhysical + "free"
        property string memApplication: memPhysical + "application"
        property string memUsed: memPhysical + "used"
        property string swap: "mem/swap/"
        property string swapUsed: swap + "used"
        property string swapFree: swap + "free"

        property double totalCpuLoad: .0
        property int averageCpuClock: 0
        property int ramUsedBytes: 0
        property double ramUsedProportion: 0
        property int swapUsedBytes: 0
        property double swapUsedProportion: 0

        connectedSources: [memFree, memUsed, memApplication, swapUsed, swapFree, averageClock, totalLoad ]
        
        onNewData: {
            if (data.value === undefined) {
                return
            }
            if (sourceName == memApplication) {
                ramUsedBytes = parseInt(data.value)
                ramUsedProportion = fitMemoryUsage(data.value)
            }
            else if (sourceName == swapUsed) {
                swapUsedBytes = parseInt(data.value)
                swapUsedProportion = fitSwapUsage(data.value)
            }
            else if (sourceName == totalLoad) {
                totalCpuLoad = data.value / 100
            }
            else if (sourceName == averageClock) {
                averageCpuClock = parseInt(data.value)
                allUsageProportionChanged()
            }
        }
        interval: 1000 * plasmoid.configuration.updateInterval
    }
    
    function fitMemoryUsage(usage) {
        var memFree = dataSource.data[dataSource.memFree]
        var memUsed = dataSource.data[dataSource.memUsed]
        if (!memFree || !memUsed) {
            return 0
        }
        return (usage / (parseFloat(memFree.value) +
                         parseFloat(memUsed.value)))
    }

    function fitSwapUsage(usage) {
        var swapFree = dataSource.data[dataSource.swapFree]
        if (!swapFree) {
            return 0
        }
        return (usage / (parseFloat(usage) + parseFloat(swapFree.value)))
    }
    
    ListModel {
        id: cpuGraphModel
    }
    
    ListModel {
        id: ramGraphModel
    }
    
    ListModel {
        id: swapGraphModel
    }
    
    function getHumanReadableMemory(memBytes) {
        var megaBytes = memBytes / 1024
        if (megaBytes <= 1024) {
            return Math.round(megaBytes) + 'M'
        }
        return Math.round(megaBytes / 1024 * 100) / 100 + 'G'
    }
    
    function getHumanReadableClock(clockMhz) {
        var clockNumber = clockMhz
        if (clockNumber < 1000) {
            return clockNumber + 'MHz'
        }
        clockNumber = clockNumber / 1000
        var floatingPointCount = 100
        if (clockNumber >= 10) {
            floatingPointCount = 10
        }
        return Math.round(clockNumber * floatingPointCount) / floatingPointCount + 'GHz'
    }
    
    function allUsageProportionChanged() {
        
        var totalCpuProportion = dataSource.totalCpuLoad
        var totalRamProportion = dataSource.ramUsedProportion
        var totalSwapProportion = dataSource.swapUsedProportion
        
        cpuPercentText.text = Math.round(totalCpuProportion * 100) + '%'
        cpuPercentText.color = totalCpuProportion > 0.9 ? warningColor : theme.textColor
        averageClockText.text = getHumanReadableClock(dataSource.averageCpuClock)
        
        ramPercentText.text = getHumanReadableMemory(dataSource.ramUsedBytes)
        ramPercentText.color = totalRamProportion > 0.9 ? warningColor : theme.textColor
        swapPercentText.text = getHumanReadableMemory(dataSource.swapUsedBytes)
        swapPercentText.color = totalSwapProportion > 0.9 ? warningColor : theme.textColor
        swapPercentText.visible = !swapInfoText.visible && totalSwapProportion > 0
        
        if (showCpuMonitor) {
            addGraphData(cpuGraphModel, totalCpuProportion * itemHeight, graphGranularity)
        }
        if (showRamMonitor) {
            addGraphData(ramGraphModel, totalRamProportion * itemHeight, graphGranularity)
            addGraphData(swapGraphModel, totalSwapProportion * itemHeight, graphGranularity)
        }
    }
    
    function addGraphData(model, itemHeight, graphGranularity) {
        
        // initial fill up
        while (model.count < graphGranularity) {
            model.append({
                'graphItemHeight': 0
            })
        }
        
        var newItem = {
            'graphItemHeight': itemHeight
        }
        
        model.append(newItem)
        model.remove(0)
    }
    
    onShowClockChanged: {
        averageClockText.visible = showClock
    }
    
    Item {
        id: cpuMonitor
        width: itemWidth
        height: itemHeight
        
        visible: showCpuMonitor
        
        HistoryGraph {
            anchors.fill: parent
            listViewModel: cpuGraphModel
            barColor: theme.highlightColor
        }
        
        Item {
            id: cpuTextContainer
            anchors.fill: parent
            
            Text {
                id: cpuInfoText
                anchors.right: parent.right
                text: 'CPU'
                font.family: textFontFamily
                color: theme.highlightColor
                font.pointSize: fontPointSize
                visible: false
            }
            
            Text {
                id: cpuPercentText
                anchors.right: parent.right
                font.family: textFontFamily
                color: theme.textColor
                font.pointSize: fontPointSize
            }
            
            Text {
                id: averageClockText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                font.family: textFontFamily
                color: theme.textColor
                font.pointSize: fontPointSize
                visible: showClock
            }
            
            Text {
                id: averageClockInfoText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                font.family: textFontFamily
                color: theme.textColor
                font.pointSize: fontPointSize
                text: 'Clock'
                visible: false
            }
        
        }
        
        DropShadow {
            anchors.fill: cpuTextContainer
            radius: 3
            samples: 8
            spread: 0.8
            fast: true
            color: theme.backgroundColor
            source: cpuTextContainer
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            
            onEntered: {
                cpuInfoText.visible = true
                cpuPercentText.visible = false
                averageClockInfoText.visible = showClock && true
                averageClockText.visible = false
            }
            
            onExited: {
                cpuInfoText.visible = false
                cpuPercentText.visible = true
                averageClockInfoText.visible = false
                averageClockText.visible = showClock && true
            }
        }
    }
    
    Item {
        id: ramMonitor
        width: itemWidth
        height: itemHeight
        anchors.left: parent.left
        anchors.leftMargin: showCpuMonitor && !verticalLayout ? itemWidth + itemMargin : 0
        anchors.top: parent.top
        anchors.topMargin: showCpuMonitor && verticalLayout ? itemWidth + itemMargin : 0
        
        visible: showRamMonitor
        
        HistoryGraph {
            listViewModel: ramGraphModel
            barColor: theme.highlightColor
        }
        
        HistoryGraph {
            listViewModel: swapGraphModel
            barColor: '#FF0000'
        }
        
        Item {
            id: ramTextContainer
            anchors.fill: parent
            
            Text {
                id: ramInfoText
                text: 'RAM'
                font.family: textFontFamily
                color: theme.highlightColor
                font.pointSize: fontPointSize
                anchors.right: parent.right
                visible: false
            }
            
            Text {
                id: ramPercentText
                anchors.right: parent.right
                font.family: textFontFamily
                color: theme.textColor
                font.pointSize: fontPointSize
            }
            
            Text {
                id: swapPercentText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                font.family: textFontFamily
                color: theme.textColor
                font.pointSize: fontPointSize
            }
            
            Text {
                id: swapInfoText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                font.family: textFontFamily
                color: '#FF0000'
                font.pointSize: fontPointSize
                text: 'Swap'
                visible: false
            }
            
        }
        
        DropShadow {
            anchors.fill: ramTextContainer
            radius: 3
            samples: 8
            spread: 0.8
            fast: true
            color: theme.backgroundColor
            source: ramTextContainer
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            
            onEntered: {
                ramInfoText.visible = true
                ramPercentText.visible = false
                swapInfoText.visible = true
                swapPercentText.visible = false
            }
            
            onExited: {
                ramInfoText.visible = false
                ramPercentText.visible = true
                swapInfoText.visible = false
                swapPercentText.visible = true
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            kRun.openUrl(apps.data["ksysguard.desktop"].entryPath)
        }
    }
    
}
