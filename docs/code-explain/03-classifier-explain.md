modules/classifier.py

This `ProcessClassifier` class is used to classify processes based on their name and command. It has a single class method `classify` which takes in a `name` and a `cmd` and returns a string representing the process type. The method uses a series of if statements to determine the process type based on the input parameters. Here's a summary of what each if statement does:

- If the `name` is in the `Config.KNOWN_CLASSES` dictionary, it returns the corresponding value.
- If the `cmd` contains ".app/" in its path, it returns "USER_APP".
- If the `name` starts with "com.apple.", it returns "BACKGROUND_SERVICE".
- If the `name` ends with "d" and does not contain "Helper", it returns "BACKGROUND_SERVICE".
- If the `name` is one of the specified user applications, it returns "USER_APP".
- If the `cmd` contains "/usr/libexec/" in its path, it returns "BACKGROUND_SERVICE".
- If none of the above conditions are met, it returns "USER_APP".
