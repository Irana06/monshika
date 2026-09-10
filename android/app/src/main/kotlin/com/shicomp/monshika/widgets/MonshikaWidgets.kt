package com.shicomp.monshika.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.shicomp.monshika.MainActivity
import com.shicomp.monshika.QuickAddActivity
import com.shicomp.monshika.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

private const val WASHI = 0xFFEDE6D6.toInt()
private const val MUTED = 0xFF9A948A.toInt()
private const val INCOME = 0xFF9CC48F.toInt()
private const val EXPENSE = 0xFFE0605A.toInt()

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
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layout)
            try {
                bind(context, views, widgetData)
            } catch (e: Exception) {
                // Data belum ada / rusak — tetap tampilkan layout default.
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    abstract fun bind(context: Context, v: RemoteViews, p: SharedPreferences)
}

/** 2×1 — tombol pengeluaran, ketik cepat, pemasukan. */
class QuickAddWidget : MonshikaWidget(R.layout.widget_quick_add) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        v.setOnClickPendingIntent(R.id.btn_expense, W.quickAdd(context, "expense", "form"))
        v.setOnClickPendingIntent(R.id.btn_quick, W.quickAdd(context))
        v.setOnClickPendingIntent(R.id.btn_income, W.quickAdd(context, "income", "form"))
    }
}

/** 4×2 — ringkasan saldo & arus kas bulan ini. */
class SummaryWidget : MonshikaWidget(R.layout.widget_summary) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        v.setTextViewText(R.id.total, W.str(p, "total_balance", "Buka Monshika"))
        v.setTextViewText(R.id.month, W.str(p, "month_label"))
        v.setTextViewText(R.id.income, "入 " + W.str(p, "income", "–"))
        v.setTextViewText(R.id.expense, "出 " + W.str(p, "expense", "–"))
        v.setTextViewText(R.id.safe, "今日 sisa aman " + W.str(p, "safe_today_left", "–"))
        v.setTextColor(R.id.safe, if (W.bool(p, "safe_over")) EXPENSE else 0xFFC9A45C.toInt())
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
        v.setOnClickPendingIntent(R.id.btn_expense, W.quickAdd(context, "expense"))
        v.setOnClickPendingIntent(R.id.btn_income, W.quickAdd(context, "income"))
    }
}

/** 2×2 — sisa aman dibelanjakan hari ini. */
class SafeSpendWidget : MonshikaWidget(R.layout.widget_safe_spend) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val over = W.bool(p, "safe_over")
        v.setTextViewText(R.id.safe_left, W.str(p, "safe_today_left", "–"))
        v.setTextColor(R.id.safe_left, if (over) EXPENSE else WASHI)
        v.setProgressBar(R.id.progress, 100, W.int(p, "safe_ratio").coerceIn(0, 100), false)
        v.setTextViewText(R.id.per_day, "Jatah " + W.str(p, "safe_per_day", "–") + "/hari")
        v.setTextViewText(R.id.spent, "Terpakai " + W.str(p, "today_spent", "–"))
        v.setOnClickPendingIntent(R.id.root, W.quickAdd(context, "expense"))
    }
}

/** 4×2 — grafik 7 hari (gambar dirender Flutter). */
class ChartWidget : MonshikaWidget(R.layout.widget_chart) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        v.setTextViewText(R.id.week_total, W.str(p, "week_total"))
        val path = W.str(p, "chart_image")
        val file = File(path)
        if (path.isNotEmpty() && file.exists()) {
            val bmp = BitmapFactory.decodeFile(file.absolutePath)
            if (bmp != null) {
                v.setImageViewBitmap(R.id.chart, bmp)
                v.setViewVisibility(R.id.chart, View.VISIBLE)
                v.setViewVisibility(R.id.empty, View.GONE)
            }
        } else {
            v.setViewVisibility(R.id.chart, View.GONE)
            v.setViewVisibility(R.id.empty, View.VISIBLE)
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** 4×1 — preset sekali tap, dicatat di latar belakang. */
class PresetWidget : MonshikaWidget(R.layout.widget_preset) {
    private val cells = intArrayOf(R.id.preset_0, R.id.preset_1, R.id.preset_2, R.id.preset_3)
    private val icons = intArrayOf(R.id.preset_0_icon, R.id.preset_1_icon, R.id.preset_2_icon, R.id.preset_3_icon)
    private val labels = intArrayOf(R.id.preset_0_label, R.id.preset_1_label, R.id.preset_2_label, R.id.preset_3_label)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val presets = W.array(p, "presets")
        v.setViewVisibility(R.id.empty, if (presets.length() == 0) View.VISIBLE else View.GONE)
        v.setViewVisibility(R.id.row, if (presets.length() == 0) View.GONE else View.VISIBLE)
        for (i in cells.indices) {
            if (i < presets.length()) {
                val o = presets.getJSONObject(i)
                v.setViewVisibility(cells[i], View.VISIBLE)
                v.setTextViewText(icons[i], o.optString("icon"))
                v.setTextViewText(labels[i], o.optString("name") + " " + o.optString("amount"))
                v.setOnClickPendingIntent(cells[i], W.background(context, "monshika://preset?id=" + o.optInt("id")))
            } else {
                v.setViewVisibility(cells[i], View.GONE)
            }
        }
        val last = W.str(p, "last_action")
        v.setTextViewText(R.id.last_action, last)
        v.setViewVisibility(R.id.last_action, if (last.isEmpty()) View.GONE else View.VISIBLE)
        v.setOnClickPendingIntent(R.id.empty, W.openApp(context))
    }
}

/** 4×2 — tiga budget dengan pemakaian tertinggi. */
class BudgetWidget : MonshikaWidget(R.layout.widget_budget) {
    private val rows = intArrayOf(R.id.b_0, R.id.b_1, R.id.b_2)
    private val names = intArrayOf(R.id.b_0_name, R.id.b_1_name, R.id.b_2_name)
    private val pcts = intArrayOf(R.id.b_0_pct, R.id.b_1_pct, R.id.b_2_pct)
    private val bars = intArrayOf(R.id.b_0_bar, R.id.b_1_bar, R.id.b_2_bar)
    private val lefts = intArrayOf(R.id.b_0_left, R.id.b_1_left, R.id.b_2_left)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val items = W.array(p, "budgets")
        v.setViewVisibility(R.id.empty, if (items.length() == 0) View.VISIBLE else View.GONE)
        for (i in rows.indices) {
            if (i < items.length()) {
                val o = items.getJSONObject(i)
                val pct = o.optInt("pct")
                v.setViewVisibility(rows[i], View.VISIBLE)
                v.setTextViewText(names[i], o.optString("icon") + "  " + o.optString("name"))
                v.setTextViewText(pcts[i], "$pct%")
                v.setTextColor(pcts[i], if (pct >= 100) EXPENSE else if (pct >= 80) 0xFFE6B422.toInt() else 0xFFC9A45C.toInt())
                v.setProgressBar(bars[i], 100, pct.coerceIn(0, 100), false)
                v.setTextViewText(lefts[i], "Sisa " + o.optString("left"))
            } else {
                v.setViewVisibility(rows[i], View.GONE)
            }
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** 4×2 — tagihan & jatuh tempo 14 hari ke depan. */
class UpcomingWidget : MonshikaWidget(R.layout.widget_upcoming) {
    private val rows = intArrayOf(R.id.u_0, R.id.u_1, R.id.u_2, R.id.u_3)
    private val icons = intArrayOf(R.id.u_0_icon, R.id.u_1_icon, R.id.u_2_icon, R.id.u_3_icon)
    private val titles = intArrayOf(R.id.u_0_title, R.id.u_1_title, R.id.u_2_title, R.id.u_3_title)
    private val dates = intArrayOf(R.id.u_0_date, R.id.u_1_date, R.id.u_2_date, R.id.u_3_date)
    private val amounts = intArrayOf(R.id.u_0_amount, R.id.u_1_amount, R.id.u_2_amount, R.id.u_3_amount)

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val items = W.array(p, "upcoming")
        v.setViewVisibility(R.id.empty, if (items.length() == 0) View.VISIBLE else View.GONE)
        for (i in rows.indices) {
            if (i < items.length()) {
                val o = items.getJSONObject(i)
                val income = o.optBoolean("income")
                v.setViewVisibility(rows[i], View.VISIBLE)
                v.setTextViewText(icons[i], o.optString("icon"))
                v.setTextViewText(titles[i], o.optString("title"))
                v.setTextViewText(dates[i], o.optString("date"))
                v.setTextViewText(amounts[i], (if (income) "+" else "−") + o.optString("amount"))
                v.setTextColor(amounts[i], if (income) INCOME else EXPENSE)
            } else {
                v.setViewVisibility(rows[i], View.GONE)
            }
        }
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}

/** 2×2 — progres target tabungan (omamori). */
class GoalWidget : MonshikaWidget(R.layout.widget_goal) {
    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
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
        v.setOnClickPendingIntent(R.id.root, W.openApp(context))
    }
}
