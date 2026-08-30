import java.io.IOException;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

public class RestaurantReducer
        extends Reducer<Text, Text, Text, Text> {

    private final Text result = new Text();

    @Override
    public void reduce(
            Text key,
            Iterable<Text> values,
            Context context)
            throws IOException, InterruptedException {

        String restaurantName = "";

        int orderCount = 0;

        double totalRevenue = 0.0;

        double kptSum = 0.0;
        int kptCount = 0;

        double riderWaitSum = 0.0;
        int riderWaitCount = 0;

        /*
         * Each value from Mapper:
         *
         * Restaurant Name | 1 | Total | KPT | Rider Wait
         */
        for (Text value : values) {

            String[] fields =
                    value.toString().split("\\|", -1);

            if (fields.length < 5) {
                continue;
            }

            restaurantName = fields[0];

            // Every Mapper record represents one order
            orderCount += Integer.parseInt(fields[1]);

            // Total revenue
            if (!fields[2].isEmpty()) {
                try {
                    double val = Double.parseDouble(fields[2]);
                    if (Double.isFinite(val)) {
                        totalRevenue += val;
                    }
                } catch (NumberFormatException e) {
                    // Ignore invalid total
                }
            }

            // KPT
            if (!fields[3].isEmpty()) {
                try {
                    double val = Double.parseDouble(fields[3]);
                    if (Double.isFinite(val) && val >= 0) {
                        kptSum += val;
                        kptCount++;
                    }
                } catch (NumberFormatException e) {
                    // Ignore invalid KPT
                }
            }

            // Rider wait
            if (!fields[4].isEmpty()) {
                try {
                    double val = Double.parseDouble(fields[4]);
                    if (Double.isFinite(val) && val >= 0) {
                        riderWaitSum += val;
                        riderWaitCount++;
                    }
                } catch (NumberFormatException e) {
                    // Ignore invalid rider wait
                }
            }
        }

        double averageOrderValue = 0.0;
        double averageKpt = 0.0;
        double averageRiderWait = 0.0;

        if (orderCount > 0) {
            averageOrderValue =
                    totalRevenue / orderCount;
        }

        if (kptCount > 0) {
            averageKpt =
                    kptSum / kptCount;
        }

        if (riderWaitCount > 0) {
            averageRiderWait =
                    riderWaitSum / riderWaitCount;
        }

        /*
         * Final output:
         *
         * Restaurant ID
         * Restaurant Name
         * Order Count
         * Total Revenue
         * Average Order Value
         * Average KPT
         * Average Rider Wait
         */
        result.set(
                restaurantName + "\t" +
                orderCount + "\t" +
                String.format("%.2f", totalRevenue) + "\t" +
                String.format("%.2f", averageOrderValue) + "\t" +
                String.format("%.2f", averageKpt) + "\t" +
                String.format("%.2f", averageRiderWait)
        );

        context.write(key, result);
    }
}
