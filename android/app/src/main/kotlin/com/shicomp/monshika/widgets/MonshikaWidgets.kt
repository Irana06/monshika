package com.shicomp.monshika.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.shicomp.monshika.MainActivity
import com.shicomp.monshika.QuickAddActivity
import com.shicomp.monshika.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

private const val WASHI = 0xFFEDE6D6.toInt()
private const val MUTED = 0xFF9A948A.toInt()
private const val INCOME = 0xFF9CC48F.toInt()
private const val EXPENSE = 0xFFE0605A.toInt()

/** Ukuran widget saat ini (dp, orientasi potret). 0 = belum diketahui → anggap besar. */
data class WidgetSize(val width: Int, val height: Int) {
    fun narrowerThan(dp: Int) = width in 1 until dp
    fun shorterThan(dp: Int) = height in 1 until dp
}

/** Helper untuk membaca data yang disimpan Flutter lewat home_widget. */
internal object W {
    fun str(p: SharedPreferences, key: String, default: String = ""): String =
        (p.all[key] as? String)?.takeIf { it.isNotEmpty() } ?: default

    fun int(p: SharedPreferences, key: String): Int = (p.all[key] as? Number)?.toInt() ?: 0

    fun bool(p: SharedPreferences, key: String): Boolean = p.all[key] as? Boolean ?: false

    fun array(p: SharedPreferences, key: String): JSONArray =
        try { JSONArray(str(p, key, "[]")) } catch (e: Exception) { JSONArray() }

    fun obj(p: SharedPreferences, key: String): JSONObject? =
        try { str(p, key).takeIf { it.isNotEmpty() }?.let { JSONObject(it) } } catch (e: Exception) { null }

    fun show(v: RemoteViews, id: Int, visible: Boolean) = v.setViewVisibility(id, if (visible) View.VISIBLE else View.GONE)

    fun openApp(ctx: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse("monshika://open"))

    fun quickAdd(ctx: Context, type: String? = null, mode: String = "quick"): PendingIntent {
        val uri = StringBuilder("monshika://quickadd?mode=").append(mode)
        if (type != null) uri.append("&type=").append(type)
        return HomeWidgetLaunchIntent.getActivity(ctx, QuickAddActivity::class.java, Uri.parse(uri.toString()))
    }

    fun background(ctx: Context, uri: String): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(ctx, Uri.parse(uri))
}

abstract class MonshikaWidget(private val layout: Int) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id, widgetData)
    }

    /** Dipanggil saat pengguna me-resize widget → susun ulang sesuai ukuran baru. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences) {
        val options = manager.getAppWidgetOptions(id)
        val size = WidgetSize(
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
        )
        val views = RemoteViews(context.packageName, layout)
        try {
            bind(context, views, data, size)
        } catch (e: Exception) {
            // Data belum ada / rusak — tetap tampilkan layout default.
        }
        manager.updateAppWidget(id, views)
    }

    abstract fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize)
}

/** Catat cepat — 1×1 hanya tombol 速, 2×1 ke atas − / 速 / +. */
class QuickAddWidget : MonshikaWidget(R.layout.widget_quick_add) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val tiny = size.narrowerThan(100)
        W.show(v, R.id.btn_expense, !tiny)
        W.show(v, R.id.btn_income, !tiny)
        v.setOnClickPendingIntent(R.id.btn_expense, W.quickAdd(context, "expense", "form"))
        v.setOnClickPendingIntent(R.id.btn_quick, W.quickAdd(context))
        v.setOnClickPendingIntent(R.id.btn_income, W.quickAdd(context, "income", "form"))
    }
}

/** Ringkasan saldo & arus kas bulan ini. */
class SummaryWidget : MonshikaWidget(R.layout.widget_summary) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        v.setTextViewText(R.id.total, W.str(p, "total_balance", "Buka Monshika"))
        v.setTextViewText(R.id.month, W.str(p, "month_label"))
        v.setTextViewText(R.id.income, "入 " + W.str(p, "income", "–"))
        v.setTextViewText(R.id.expense, "出 " + W.str(p, "expense", "–"))
        v.setTextViewText(R.id.safe, "今日 sisa aman " + W.str(p, "safe_today_left", "–"))
        v.setTextColor(R.id.safe, if (W.bool(p, "safe_over")) EXPENSE else 0xFFC9A45C.toInt())

        W.show(v, R.id.month, !size.narrowerThan(170))
        W.show(v, R.id.flow_row, !size.shorterThan(80))
        W.show(v, R.id.safe, !size.shorterThan(100))
        W.show(v, R.id.buttons_row, !size.shorterThan(140))

        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
        v.setOnClickPendingIntent(R.id.btn_expense, W.quickAdd(context, "expense"))
        v.setOnClickPendingIntent(R.id.btn_income, W.quickAdd(context, "income"))
    }
}

/** Sisa aman dibelanjakan hari ini. */
class SafeSpendWidget : MonshikaWidget(R.layout.widget_safe_spend) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val over = W.bool(p, "safe_over")
        v.setTextViewText(R.id.safe_left, W.str(p, "safe_today_left", "–"))
        v.setTextColor(R.id.safe_left, if (over) EXPENSE else WASHI)
        v.setProgressBar(R.id.progress, 100, W.int(p, "safe_ratio").coerceIn(0, 100), false)
        v.setTextViewText(R.id.per_day, "Jatah " + W.str(p, "safe_per_day", "–") + "/hari")
        v.setTextViewText(R.id.spent, "Terpakai " + W.str(p, "today_spent", "–"))

        W.show(v, R.id.progress, !size.shorterThan(70))
        W.show(v, R.id.per_day, !size.shorterThan(90))
        W.show(v, R.id.spent, !size.shorterThan(110))

        v.setOnClickPendingIntent(R.id.root, W.quickAdd(context, "expense"))
    }
}

/** Grafik 7 hari (gambar dirender Flutter). */
class ChartWidget : MonshikaWidget(R.layout.widget_chart) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        v.setTextViewText(R.id.week_total, W.str(p, "week_total"))
        W.show(v, R.id.header_row, !size.shorterThan(90))
        val path = W.str(p, "chart_image")
        val file = File(path)
        val bmp = if (path.isNotEmpty() && file.exists()) BitmapFactory.decodeFile(file.absolutePath) else null
        if (bmp != null) {
            v.setImageViewBitmap(R.id.chart, bmp)
            W.show(v, R.id.chart, true)
            W.show(v, R.id.empty, false)
        } else {
            W.show(v, R.id.chart, false)
            W.show(v, R.id.empty, true)
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** Preset sekali tap, dicatat di latar belakang. Jumlah tombol mengikuti lebar widget. */
class PresetWidget : MonshikaWidget(R.layout.widget_preset) {
    private val cells = intArrayOf(R.id.preset_0, R.id.preset_1, R.id.preset_2, R.id.preset_3)
    private val icons = intArrayOf(R.id.preset_0_icon, R.id.preset_1_icon, R.id.preset_2_icon, R.id.preset_3_icon)
    private val labels = intArrayOf(R.id.preset_0_label, R.id.preset_1_label, R.id.preset_2_label, R.id.preset_3_label)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val presets = W.array(p, "presets")
        val maxCells = if (size.width <= 0) 4 else (size.width / 62).coerceIn(1, 4)
        val count = minOf(presets.length(), maxCells)
        val showLabels = !size.shorterThan(56)
        W.show(v, R.id.empty, presets.length() == 0)
        W.show(v, R.id.row, presets.length() > 0)
        for (i in cells.indices) {
            if (i < count) {
                val o = presets.getJSONObject(i)
                W.show(v, cells[i], true)
                W.show(v, labels[i], showLabels)
                v.setTextViewText(icons[i], o.optString("icon"))
                v.setTextViewText(labels[i], o.optString("name") + " " + o.optString("amount"))
                v.setOnClickPendingIntent(cells[i], W.background(context, "monshika://preset?id=" + o.optInt("id")))
            } else {
                W.show(v, cells[i], false)
            }
        }
        val last = W.str(p, "last_action")
        v.setTextViewText(R.id.last_action, last)
        W.show(v, R.id.last_action, last.isNotEmpty() && !size.shorterThan(80))
        v.setOnClickPendingIntent(R.id.empty, W.openApp(context))
    }
}

/** Budget dengan pemakaian tertinggi. Jumlah baris mengikuti tinggi widget. */
class BudgetWidget : MonshikaWidget(R.layout.widget_budget) {
    private val rows = intArrayOf(R.id.b_0, R.id.b_1, R.id.b_2)
    private val names = intArrayOf(R.id.b_0_name, R.id.b_1_name, R.id.b_2_name)
    private val pcts = intArrayOf(R.id.b_0_pct, R.id.b_1_pct, R.id.b_2_pct)
    private val bars = intArrayOf(R.id.b_0_bar, R.id.b_1_bar, R.id.b_2_bar)
    private val lefts = intArrayOf(R.id.b_0_left, R.id.b_1_left, R.id.b_2_left)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val items = W.array(p, "budgets")
        val showHeader = !size.shorterThan(80)
        val maxRows = if (size.height <= 0) 3 else ((size.height - (if (showHeader) 36 else 16)) / 40).coerceIn(1, 3)
        W.show(v, R.id.header, showHeader)
        W.show(v, R.id.empty, items.length() == 0)
        for (i in rows.indices) {
            if (i < items.length() && i < maxRows) {
                val o = items.getJSONObject(i)
                val pct = o.optInt("pct")
                W.show(v, rows[i], true)
                v.setTextViewText(names[i], o.optString("icon") + "  " + o.optString("name"))
                v.setTextViewText(pcts[i], "$pct%")
                v.setTextColor(pcts[i], if (pct >= 100) EXPENSE else if (pct >= 80) 0xFFE6B422.toInt() else 0xFFC9A45C.toInt())
                v.setProgressBar(bars[i], 100, pct.coerceIn(0, 100), false)
                v.setTextViewText(lefts[i], "Sisa " + o.optString("left"))
                W.show(v, lefts[i], !size.shorterThan(90))
            } else {
                W.show(v, rows[i], false)
            }
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** Tagihan & jatuh tempo 14 hari ke depan. Jumlah baris mengikuti tinggi widget. */
class UpcomingWidget : MonshikaWidget(R.layout.widget_upcoming) {
    private val rows = intArrayOf(R.id.u_0, R.id.u_1, R.id.u_2, R.id.u_3)
    private val icons = intArrayOf(R.id.u_0_icon, R.id.u_1_icon, R.id.u_2_icon, R.id.u_3_icon)
    private val titles = intArrayOf(R.id.u_0_title, R.id.u_1_title, R.id.u_2_title, R.id.u_3_title)
    private val dates = intArrayOf(R.id.u_0_date, R.id.u_1_date, R.id.u_2_date, R.id.u_3_date)
    private val amounts = intArrayOf(R.id.u_0_amount, R.id.u_1_amount, R.id.u_2_amount, R.id.u_3_amount)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val items = W.array(p, "upcoming")
        val showHeader = !size.shorterThan(80)
        val maxRows = if (size.height <= 0) 4 else ((size.height - (if (showHeader) 36 else 16)) / 34).coerceIn(1, 4)
        W.show(v, R.id.header, showHeader)
        W.show(v, R.id.empty, items.length() == 0)
        for (i in rows.indices) {
            if (i < items.length() && i < maxRows) {
                val o = items.getJSONObject(i)
                val income = o.optBoolean("income")
                W.show(v, rows[i], true)
                W.show(v, icons[i], !size.narrowerThan(150))
                v.setTextViewText(icons[i], o.optString("icon"))
                v.setTextViewText(titles[i], o.optString("title"))
                v.setTextViewText(dates[i], o.optString("date"))
                v.setTextViewText(amounts[i], (if (income) "+" else "−") + o.optString("amount"))
                v.setTextColor(amounts[i], if (income) INCOME else EXPENSE)
            } else {
                W.show(v, rows[i], false)
            }
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** Progres target tabungan. 1×1 hanya ikon + persen. */
class GoalWidget : MonshikaWidget(R.layout.widget_goal) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences, size: WidgetSize) {
        val o = W.obj(p, "goal")
        if (o == null) {
            v.setTextViewText(R.id.icon, "夢")
            v.setTextViewText(R.id.name, "Belum ada target")
            v.setTextViewText(R.id.pct, "")
            v.setTextViewText(R.id.amounts, "Buat di Monshika")
            v.setProgressBar(R.id.bar, 100, 0, false)
        } else {
            v.setTextViewText(R.id.icon, o.optString("icon"))
            v.setTextColor(R.id.icon, o.optLong("color", 0xFFE8A6B5).toInt())
            v.setTextViewText(R.id.name, o.optString("name"))
            v.setTextViewText(R.id.pct, o.optInt("pct").toString() + "%")
            v.setTextViewText(R.id.amounts, o.optString("saved") + " / " + o.optString("target"))
            v.setProgressBar(R.id.bar, 100, o.optInt("pct").coerceIn(0, 100), false)
        }
        v.setTextColor(R.id.name, WASHI)
        v.setTextColor(R.id.amounts, MUTED)

        val compact = size.shorterThan(100)
        W.show(v, R.id.name, !size.shorterThan(80))
        W.show(v, R.id.bar, !compact)
        W.show(v, R.id.amounts, !size.shorterThan(120))

        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}
