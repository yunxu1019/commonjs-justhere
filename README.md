# CommonJS Justhere
更新了原 `CommonJS Everywhere` 中的一些陈旧的依赖项。[English Version](./README-CommonJS-Everywhere.md)

# CommonJS Everywhere

CommonJS（节点模块）浏览器绑定器，具有从缩小的JS绑定到原始源的源映射、浏览器重写的别名以及任意编译到JS语言支持的扩展性。

## 安装

    npm install -g commonjs-everywhere

## 使用

### 命令行

    $ bin/cjsify --help

      用法: cjsify OPT* path/to/entry-file.ext OPT*

      -a, --alias ALIAS:TO      将ALIAS标识的文件的要求替换为`TO`
      -h, --handler EXT:MODULE  使用扩展名EXT和MODULE模块处理文件
      -m, --minify              压缩输出
      -o, --output FILE         输出到FILE而不是stdout
      -r, --root DIR            相对路径是相对于DIR的；默认值：cwd
      -s, --source-map FILE     将源映射输出到FILE
      -v, --verbose             输出详细日志
      -w, --watch               监视输入文件/依赖项的更改并重新生成捆绑包
      -x, --export NAME         指定输出名为NAME
      --deps                    仅列出依赖项而不绑定
      --help                    显示帮助信息并退出
      --ignore-missing          当依赖项解析失败时继续
      --inline-source-map       将sourcemap作为数据URI包含在生成的包中
      --inline-sources          在生成的sourcemap中包含源内容；默认值：on
      --node                    包括process对象；模拟node环境；默认值：on
      --version                 显示版本号并退出

*注意:* 使用`-`作为条目文件接受javascript而不是stdin.

*注意:* 要禁用某个选项，请在其前面加上 `no-` ，例如: `--no-node`

#### 示例:

一般用法

```bash
cjsify src/entry-file.js --export MyLibrary --source-map my-library.js.map >my-library.js
```

监视条目文件及其依赖项，以及新添加的依赖项。请注意，只有需要重建的文件在其依赖项时才被访问。这是一种比简单地重建一切更有效的方法。

```bash
cjsify -wo my-library.js -x MyLibrary src/entry-file.js
```

使用特定于浏览器的版本`/lib/node compatible.js`（记住使用“根”相对路径作为别名）。空别名目标用于在需要源模块时将错误延迟到运行时（在本例中为`fs`）。

```bash
cjsify -a /lib/node-compatible.js:/lib/browser-compatible.js -a fs: -x MyLibrary lib/entry-file.js
```

### 模块接口

#### `cjsify(entryPoint, root, options)` → Spidermonkey AST
绑定给定文件及其依赖项；返回绑定的spidermonkey AST表示。通过'escodegen'运行ast以生成js代码。

* `entrypoint`是一个相对于`process.cwd()`的文件，该文件将是标记为包含在包中的初始模块以及导出的模块
* `root`相对于哪个路径；默认为'process.cwd()`.
* ` options`是一个可选对象（默认为‘’’），具有以下零个或多个属性
    * ` export`：要添加到全局作用域的变量名；从'entrypoint'模块分配导出的对象。可以提供任何有效的[左侧表达式]（http://es5.github.com/x11.2）。
    * `aliases`：其键和值为“根”根路径（`/src/file.js`）的对象，表示将替换的值需要解析为关联键
    * ` handlers`：一个对象，其键是文件扩展名（`.roy`），其值是从文件内容到spidermonkey格式js ast（如esprima生成的格式）或js字符串的函数。默认情况下包括coffeescript和json的处理程序。如果没有为文件扩展名定义处理程序，则假定它是javascript。
    * `node`：一个错误的值会导致绑定阶段忽略模拟节点环境的'process'存根。
    * `verbose`: 将其他操作信息记录到stderr
    * `ignoreMissing`: 忽略依赖缺失的问题

## 示例

### 命令行用法

假设我们有以下目录树：

```
* todos/
  * components/
    * users/
      - model.coffee
    * todos/
      - index.coffee
  * public/
    * javascripts/
```
运行以下命令将`index.coffee`及其依赖项导出为`app.todos`。

```
cjsify -o public/javascripts/app.js -x App.Todos -r components components/todos/index.coffee
```

由于上面的命令将`components`指定为unqualified requires的根目录，因此我们可以使用`require 'users/model'`来要求'components/users/model.coffee'。输出文件将是'public/javascripts/app.js`。
### Node 模块示例

```coffee
jsAst = (require 'commonjs-everywhere').cjsify 'src/entry-file.coffee', __dirname,
  export: 'MyLibrary'
  aliases:
    '/src/module-that-only-works-in-node.coffee': '/src/module-that-does-the-same-thing-in-the-browser.coffee'
  handlers:
    '.roy': (roySource, filename) ->
      # Roy编译器现在输出JS代码，所以我们用esprima分析它。
      (require 'esprima').parse (require 'roy').compile roySource, {filename}

{map, code} = (require 'escodegen').generate jsAst,
  sourceMapRoot: __dirname
  sourceMapWithCode: true
  sourceMap: true
```

### 简单输出
