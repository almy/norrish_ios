# norrish_ios

## Integration Tests (Backend)

Set these environment variables on the `healthScannerTests` scheme (Test > Arguments > Environment Variables):

```
API_BASE_URL=https://norrish.myftiu.al
API_KEY=your-api-key
```

Optional overrides:

```
TEST_EAN_EXISTING=00000073107552
TEST_EAN_OPENDATA=3017620425035
TEST_PLATE_IMAGE_PATH=/absolute/path/to/plate.jpg
TEST_OPENDATA_EXPECTED_BRAND=ExampleBrand
```

The plate image defaults to `healthScannerTests/resources/plate.jpg` bundled with the test target.
