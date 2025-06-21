#ifndef CHART_COMMENT_MQH
#define CHART_COMMENT_MQH

class ChartComment
{
public:
    // Method to display a single-line comment
    void Show(string header, string message)
    {
        string output = header + "\n" + message;
        Comment(output);
    }

    // Method to display multiple lines using an array
    void Show(string header, string &messages[], int size)
    {
        string output = header + "\n";
        for (int i = 0; i < size; i++)
        {
            output += messages[i] + "\n";
        }
        Comment(output);
    }

    // Clear the comment
    void Clear()
    {
        Comment("");
    }
};

#endif
