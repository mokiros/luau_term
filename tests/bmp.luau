return function(imageData: buffer, width: number, height: number)
	local extraBytes = width % 4
	local rowBytes = 3 * width + extraBytes
	local rgbSize = height * rowBytes
	local bmpBuffer = buffer.create(54 + rgbSize)

	buffer.writeu16(bmpBuffer, 0, 0x4d42)
	buffer.writeu32(bmpBuffer, 2, buffer.len(bmpBuffer))
	buffer.writeu32(bmpBuffer, 10, 54)
	buffer.writeu32(bmpBuffer, 14, 40)
	buffer.writeu32(bmpBuffer, 18, width)
	buffer.writei32(bmpBuffer, 22, -height)
	buffer.writeu16(bmpBuffer, 26, 1)
	buffer.writeu16(bmpBuffer, 28, 24)
	buffer.writeu32(bmpBuffer, 34, rgbSize)

	local i = 0

	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local p = 54 + y * rowBytes + x * 3

			buffer.writeu8(bmpBuffer, p, buffer.readu8(imageData, i + 2))
			buffer.writeu8(bmpBuffer, p + 1, buffer.readu8(imageData, i + 1))
			buffer.writeu8(bmpBuffer, p + 2, buffer.readu8(imageData, i))

			i += 4
		end
	end

	return bmpBuffer
end
