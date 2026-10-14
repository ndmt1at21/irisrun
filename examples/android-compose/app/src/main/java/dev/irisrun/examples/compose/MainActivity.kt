package dev.irisrun.examples.compose

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) { App() }
            }
        }
    }
}

// Longer than the screen, so the list scrolls.
private val fruits = listOf(
    "Xoài", "Sầu riêng", "Măng cụt", "Chôm chôm", "Thanh long", "Vải", "Nhãn", "Mít", "Bưởi", "Chuối",
    "Dứa", "Đu đủ", "Ổi", "Na", "Chanh dây", "Dưa hấu", "Hồng xiêm", "Vú sữa", "Mận", "Khế",
)

@Composable
private fun App() {
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    when (val fruit = selected) {
        null -> Home(onSelect = { selected = it })
        else -> {
            BackHandler { selected = null }
            Text("$fruit — press back to return", Modifier.padding(24.dp), style = MaterialTheme.typography.headlineSmall)
        }
    }
}

@Composable
private fun Home(onSelect: (String) -> Unit) {
    var count by rememberSaveable { mutableIntStateOf(0) }
    var name by rememberSaveable { mutableStateOf("") }
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Jetpack Compose on Iris", style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Your name") },
            modifier = Modifier.fillMaxWidth(),
        )
        Text(if (name.isBlank()) "Type your name" else "Xin chào, $name!")
        Button(onClick = { count++ }, Modifier.fillMaxWidth()) { Text("Tapped $count times") }
        LazyColumn {
            items(fruits) { fruit ->
                Text(
                    fruit,
                    Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(fruit) }
                        .padding(vertical = 14.dp),
                )
                HorizontalDivider()
            }
        }
    }
}
