package com.mediahub.mediacenter

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class MusicWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.music_widget)
            val widgetData = HomeWidgetPlugin.getData(context)

            val title = widgetData.getString("title", "لا توجد أغنية")
            val artist = widgetData.getString("artist", "")
            val isPlaying = widgetData.getBoolean("isPlaying", false)

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(
                R.id.widget_play,
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
