import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

public class RestaurantMapper
        extends Mapper<LongWritable, Text, Text, Text> {

    private final Text outKey = new Text();
    private final Text outValue = new Text();

    @Override
    public void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {

        String line = value.toString();

        // Skip CSV header
        if (key.get() == 0 && line.startsWith("Restaurant ID")) {
            return;
        }

        // Parse CSV safely
        String[] fields = parseCSV(line);

        // Need columns up to Rider wait time
        if (fields.length < 26) {
            return;
        }

        String restaurantId = fields[0].trim();
        String restaurantName = fields[1].trim();
        String total = fields[18].trim();
        String kpt = fields[24].trim();
        String riderWait = fields[25].trim();

        // Ignore rows without restaurant ID
        if (restaurantId.isEmpty()) {
            return;
        }

        /*
         * Key:
         *     Restaurant ID
         *
         * Value:
         *     Restaurant Name | 1 | Total | KPT | Rider Wait
         */
        outKey.set(restaurantId);

        outValue.set(
                restaurantName + "|" +
                "1|" +
                total + "|" +
                kpt + "|" +
                riderWait
        );

        context.write(outKey, outValue);
    }

    /**
     * Parses a CSV line while respecting quoted fields.
     */
    private String[] parseCSV(String line) {

        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();

        boolean insideQuotes = false;

        for (int i = 0; i < line.length(); i++) {

            char c = line.charAt(i);

            if (c == '"') {

                // Handle escaped quote ""
                if (insideQuotes
                        && i + 1 < line.length()
                        && line.charAt(i + 1) == '"') {

                    current.append('"');
                    i++;

                } else {
                    insideQuotes = !insideQuotes;
                }

            } else if (c == ',' && !insideQuotes) {

                fields.add(current.toString());
                current.setLength(0);

            } else {

                current.append(c);
            }
        }

        // Add final field
        fields.add(current.toString());

        return fields.toArray(new String[0]);
    }
}
