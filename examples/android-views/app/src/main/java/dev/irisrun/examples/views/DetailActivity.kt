package dev.irisrun.examples.views

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class DetailActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)
        findViewById<TextView>(R.id.detail).text =
            getString(R.string.detail, intent.getStringExtra(EXTRA_NAME).orEmpty())
    }

    companion object {
        const val EXTRA_NAME = "name"
    }
}
