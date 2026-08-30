import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class RestaurantDriver {

    public static void main(String[] args) throws Exception {

        Configuration conf = new Configuration();

        Job job = Job.getInstance(
                conf,
                "Restaurant Operational Performance"
        );

        // Set the main driver class
        job.setJarByClass(RestaurantDriver.class);

        // Set Mapper and Reducer
        job.setMapperClass(RestaurantMapper.class);
        job.setReducerClass(RestaurantReducer.class);

        // Mapper output types
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);

        // Final Reducer output types
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);

        // HDFS input
        FileInputFormat.addInputPath(
                job,
                new Path("/food_delivery/input/orders_clean.csv")
        );

        // HDFS output
        FileOutputFormat.setOutputPath(
                job,
                new Path("/food_delivery/output/restaurant_performance")
        );

        // Run the job
        System.exit(
                job.waitForCompletion(true)
                        ? 0
                        : 1
        );
    }
}
