"""
AWS Lambda function to send daily billing email via SNS.

This function retrieves the current month-to-date AWS charges and sends
a formatted summary via SNS email notification.

Environment Variables:
    SNS_TOPIC_ARN: ARN of the SNS topic to publish billing notifications

Handler: daily_billing_email.lambda_handler

Required IAM Permissions:
    - ce:GetCostAndUsage
    - sns:Publish
"""

import json
import os
from datetime import datetime, timedelta
from decimal import Decimal

import boto3


def get_month_to_date_cost():
    """
    Retrieve month-to-date cost from AWS Cost Explorer.

    Returns:
        dict: Cost data including total amount and breakdown by service
    """
    ce_client = boto3.client('ce')

    # Calculate date range: first day of month to today
    today = datetime.now()
    start_date = today.replace(day=1).strftime('%Y-%m-%d')
    end_date = (today + timedelta(days=1)).strftime('%Y-%m-%d')

    # Get overall cost
    response = ce_client.get_cost_and_usage(
        TimePeriod={
            'Start': start_date,
            'End': end_date
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {
                'Type': 'DIMENSION',
                'Key': 'SERVICE'
            }
        ]
    )

    return response


def format_billing_message(cost_data):
    """
    Format the cost data into a human-readable message.

    Args:
        cost_data (dict): Cost data from Cost Explorer API

    Returns:
        str: Formatted billing message
    """
    today = datetime.now()
    month_name = today.strftime('%B %Y')

    # Parse results
    results = cost_data.get('ResultsByTime', [])
    if not results:
        return f"No billing data available for {month_name}"

    total_cost = Decimal('0')
    service_costs = []

    # Extract costs by service
    groups = results[0].get('Groups', [])
    for group in groups:
        service_name = group.get('Keys', ['Unknown'])[0]
        amount = Decimal(group.get('Metrics', {}).get('UnblendedCost', {}).get('Amount', '0'))

        if amount > 0:
            total_cost += amount
            service_costs.append((service_name, amount))

    # Sort services by cost (highest first)
    service_costs.sort(key=lambda x: x[1], reverse=True)

    # Build message
    message_lines = [
        f"AWS Billing Report for {month_name}",
        f"Report Date: {today.strftime('%Y-%m-%d')}",
        "=" * 60,
        f"\nTotal Month-to-Date Cost: ${total_cost:.2f}",
        "\nCost Breakdown by Service:",
        "-" * 60
    ]

    # Add top services (limit to top 15 to keep email concise)
    for service, cost in service_costs[:15]:
        percentage = (cost / total_cost * 100) if total_cost > 0 else 0
        message_lines.append(f"  {service:<40} ${cost:>10.2f} ({percentage:>5.1f}%)")

    if len(service_costs) > 15:
        other_cost = sum(cost for _, cost in service_costs[15:])
        percentage = (other_cost / total_cost * 100) if total_cost > 0 else 0
        message_lines.append(f"  {'Other Services':<40} ${other_cost:>10.2f} ({percentage:>5.1f}%)")

    message_lines.append("-" * 60)
    message_lines.append(f"\nNote: This report shows charges from {today.strftime('%B 1, %Y')} to {today.strftime('%B %d, %Y')}")
    message_lines.append("Final charges may vary based on usage throughout the rest of the month.")

    return "\n".join(message_lines)


def send_sns_notification(message):
    """
    Send billing notification via SNS.

    Args:
        message (str): Formatted billing message

    Returns:
        dict: SNS publish response
    """
    sns_client = boto3.client('sns')
    topic_arn = os.environ.get('SNS_TOPIC_ARN')

    if not topic_arn:
        raise ValueError("SNS_TOPIC_ARN environment variable is not set")

    today = datetime.now()
    subject = f"AWS Billing Report - {today.strftime('%B %d, %Y')}"

    response = sns_client.publish(
        TopicArn=topic_arn,
        Subject=subject,
        Message=message
    )

    return response


def lambda_handler(event, context):
    """
    Lambda handler function for daily billing email.

    This function is triggered daily (typically via CloudWatch Events) to:
    1. Retrieve current month-to-date AWS costs
    2. Format the cost data into a readable message
    3. Send the message via SNS email notification

    Args:
        event (dict): Lambda event data (not used)
        context (object): Lambda context object

    Returns:
        dict: Response with status code and message
    """
    try:
        print("Starting daily billing email function")

        # Get cost data
        print("Fetching month-to-date costs from Cost Explorer")
        cost_data = get_month_to_date_cost()

        # Format message
        print("Formatting billing message")
        message = format_billing_message(cost_data)
        print(f"Billing message:\n{message}")

        # Send via SNS
        print("Sending SNS notification")
        sns_response = send_sns_notification(message)
        print(f"SNS MessageId: {sns_response.get('MessageId')}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Billing email sent successfully',
                'messageId': sns_response.get('MessageId')
            })
        }

    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        raise
