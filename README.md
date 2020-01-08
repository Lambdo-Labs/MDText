# MDText

MDText is a markdown render library built in and for SwiftUI


## Usage:
```swift
import MDText
struct ContentView: View {
    var markdown = 
    """
    ** Hello MDText **
    """
    
    var body: some View {
        MDText(markdown: markdown)
    }
}
```

##  Features:
- header 
- link 
- bold
- hyperlink
- emphasis
 

## Planned: 

del, quote, inline, ul, ol, blockquotes

## Installation
Using Xcode 11

```
menu > file > Swift Packages > Add package dependency...
```

enter package url: https://github.com/Lambdo-Labs/MDText

