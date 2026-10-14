package dev.irisrun.examples.views

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val name = findViewById<EditText>(R.id.name)
        val greeting = findViewById<TextView>(R.id.greeting)
        findViewById<Button>(R.id.greet).setOnClickListener {
            greeting.text = getString(R.string.greeting, name.text.toString().ifBlank { "Iris" })
        }
        findViewById<Button>(R.id.open_detail).setOnClickListener {
            startActivity(
                Intent(this, DetailActivity::class.java)
                    .putExtra(DetailActivity.EXTRA_NAME, name.text.toString()),
            )
        }
    }
}
