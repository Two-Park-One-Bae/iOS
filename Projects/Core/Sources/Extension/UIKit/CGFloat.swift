// The MIT License (MIT)
//
// Copyright (c) 2015 Suyeol Jeon (xoul.kr)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import CoreGraphics

public extension IntegerLiteralType {
  var f: CGFloat {
    return CGFloat(self)
  }
}

public extension FloatLiteralType {
  var f: CGFloat {
    return CGFloat(self)
  }
}

/*
 .f가 실제로 값을 하는 경우는 리터럴이 아니라 Int/Double 변수를 CGFloat으로 바꿔야 할 때, 그리고 타입이 섞인 산술식. 이런 데서는 CGFloat 변수가 .f 없이 적었을 때 자동 추론이 안 통하기때문에:
 
 
 example)
 let columns = 3        // Int
 let spacing = 16       // Int

 // ❌ 컴파일 에러: columns * spacing 은 Int라 CGFloat과 못 뺌
 let itemWidth = view.bounds.width - (columns * spacing)

 // 그래서 변환이 필요
 let itemWidth = view.bounds.width - (columns.f * spacing.f)
 // 위 .f 없이 쓰면 → CGFloat(columns) * CGFloat(spacing) 으로 길어짐
 
 
 */
